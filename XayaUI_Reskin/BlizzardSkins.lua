-------------------------------------------------------------------------------
-- BlizzardSkins.lua (XayaUI Blizzard Reskin 0.6.19): XayaUI's look on Blizzard's own windows, the minimap, tooltips, the objective
-- tracker, Battle.net toasts, pop-up dialogs, loot rolls, menus, chat bubbles, the status bars, the minimap's zone bar and tracking
-- button, and the red buttons inside Blizzard's windows. Look only: art, colour, border, mask. Nothing is moved, resized, added or
-- removed, and no Blizzard function is called to do anything. Own code, Blizzard's frames only.
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
    -- (0.6.12, her "loot roll / need, greed, transmog") GroupLootFrameTemplate draws its art on its own keys Background and Border
    -- (12.1.5 Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml:290-307); Border is tinted in the item's quality colour on every show
    -- (GroupLootFrame.lua:172-177), so our border takes that colour (read after Blizzard's OnShow) and the quality stays visible.
    -- These two keys are only faded here: other windows use Background / Border for content, so they are not in the generic ART list.
    { key = "lootroll",     label = "Loot rolls (Need, Greed, Transmog)", frames = { "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4" },
        art = { "Background", "Border" }, qualityBorder = "Border" },
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
--   windows / minimap / tooltips / tracker / toasts / menus / bubbles / statusbars / mmbuttons / buttons = true (a page ticked); winOff[key] / otOff[key] / toastOff[key] = true (left out);
--   shape = "SQUARE";
--   bgAlpha = window background opacity (0.5 - 1, default 0.95)
-------------------------------------------------------------------------------
local function Saved() local ui = rawget(_G, "CueRulesDB") and CueRulesDB.ui; local r = ui and ui.rsk; return type(r) == "table" and r or nil end
local function Cfg()
    CueRulesDB = CueRulesDB or {}; CueRulesDB.ui = CueRulesDB.ui or {}
    local r = CueRulesDB.ui.rsk
    if type(r) ~= "table" then r = {}; CueRulesDB.ui.rsk = r end
    if type(r.winOff) ~= "table" then r.winOff = {} end
    if type(r.otOff) ~= "table" then r.otOff = {} end
    if type(r.toastOff) ~= "table" then r.toastOff = {} end
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
    if m.bd and type(owner) == "table" then   -- a backdrop's own colours, read before we changed them
        local b = m.bd
        if owner.SetBackdropColor then pcall(owner.SetBackdropColor, owner, b[1], b[2], b[3], b[4]) end
        if owner.SetBackdropBorderColor then pcall(owner.SetBackdropBorderColor, owner, b[5], b[6], b[7], b[8]) end
        m.bd = nil
    end
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

-- our own background (theme window colour at Background opacity) and a 1 px border, drawn on a frame whose art is faded
local function OwnBg(f)
    local m = M(f)
    if not m.bg then
        m.bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        m.bg:SetAllPoints(f)
        m.own[#m.own + 1] = m.bg
    end
    local bg = WinBg()
    m.bg:SetColorTexture(bg[1], bg[2], bg[3], Alpha()); m.bg:Show()
    PaintEdges(Edges(f, f), WinBorder())
    return m
end

local function PaintWindow(f)
    if type(f) ~= "table" or type(f.CreateTexture) ~= "function" then return end
    if Blocked(f) then Later(function() if liveWin then PaintWindow(f) end end); return end
    for _, part in ipairs({ f, f.BorderFrame }) do
        if type(part) == "table" then
            for _, k in ipairs(ART) do Fade(f, part[k]) end
            if type(part.Inset) == "table" then Fade(f, part.Inset.Bg); Fade(f, part.Inset.NineSlice) end
        end
    end
    local e = f.GetName and entryOf[f:GetName() or ""]
    if e and e.art then for _, k in ipairs(e.art) do Fade(f, f[k]) end end
    local m = OwnBg(f)
    local qb = e and e.qualityBorder and f[e.qualityBorder]
    if type(qb) == "table" and qb.GetVertexColor then   -- the item's quality colour Blizzard put on its own border (alpha does not change it)
        local ok, r, g, b = pcall(qb.GetVertexColor, qb)
        if ok and num(r) and num(g) and num(b) then m.edgeCol = { r, g, b, 1 }; PaintEdges(m.edges, m.edgeCol) end
    end
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
-- 5. Battle.net toasts and pop-up dialogs (her "bnet alert toasts + popups"), a box each
-------------------------------------------------------------------------------
-- 12.1.5 source (Gethe/wow-ui-source 297d7aa, read as data): BNToastFrame and TimeAlertFrame (Blizzard_BNet/BNet.xml:3, 83) inherit
-- SocialToastTemplate, which inherits BackdropTemplate (Blizzard_SocialToast/SocialToast.xml:44) with no backdrop colour of its own: the
-- toast takes the theme's colours through SetBackdropColor / SetBackdropBorderColor; the colours it had are read first and given back.
-- StaticPopup1-4 (Blizzard_StaticPopup_Game/GameDialog.xml:334-349) draw their art on a child frame "BG" (Top / Bottom textures,
-- GameDialog.lua:25-28): BG is faded and our background and border are drawn, as on a window. Text and buttons are Blizzard's.
BS.TOASTS = {
    { key = "bnet",   label = "Battle.net toasts (friend online, broadcasts, time alerts)", frames = { "BNToastFrame", "TimeAlertFrame" }, kind = "backdrop" },
    { key = "popups", label = "Pop-up dialogs (confirmations, invites, Are you sure?)",    frames = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }, kind = "dialog" },
}
local liveToast = false
local hookedToast = {}
local function ToastOn(e) local r = Saved(); return PageOn("toasts") and not (r.toastOff and r.toastOff[e.key]) end
BS.ToastOn = ToastOn
local function PaintToast(f, e)
    if type(f) ~= "table" then return end
    if Blocked(f) then Later(function() if liveToast and ToastOn(e) then PaintToast(f, e) end end); return end
    local m = M(f)
    if e.kind == "backdrop" then
        if type(f.SetBackdropColor) ~= "function" then return end
        if not m.bd then
            local r, g, b, a, br, bg2, bb, ba
            if f.GetBackdropColor then r, g, b, a = f:GetBackdropColor() end
            if f.GetBackdropBorderColor then br, bg2, bb, ba = f:GetBackdropBorderColor() end
            local function n(v) return num(v) and v or 1 end
            m.bd = { n(r), n(g), n(b), n(a), n(br), n(bg2), n(bb), n(ba) }
        end
        local bg, bd = WinBg(), WinBorder()
        f:SetBackdropColor(bg[1], bg[2], bg[3], Alpha())
        if f.SetBackdropBorderColor then f:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4] or 1) end
    else
        if type(f.CreateTexture) ~= "function" then return end
        Fade(f, f.BG)
        OwnBg(f)
    end
    m.painted = true
    BS.diag.painted = BS.diag.painted + 1
end
BS.PaintToast = PaintToast
local function ApplyToasts()
    if PageOn("toasts") then
        liveToast = true
        for _, e in ipairs(BS.TOASTS) do
            for _, n in ipairs(e.frames) do
                local f = rawget(_G, n)
                if type(f) == "table" then
                    if not hookedToast[f] and type(f.HookScript) == "function" then
                        hookedToast[f] = true
                        f:HookScript("OnShow", function(self) if liveToast and ToastOn(e) then Safe(PaintToast, self, e) end end)
                    end
                    if ToastOn(e) then Safe(PaintToast, f, e) else Restore(f) end
                end
            end
        end
    elseif liveToast then
        liveToast = false
        for _, e in ipairs(BS.TOASTS) do for _, n in ipairs(e.frames) do local f = rawget(_G, n); if f then Restore(f) end end end
    end
end

-------------------------------------------------------------------------------
-- 6. Menus: right-click and dropdown menus (her "menus", Q12 "all")
-------------------------------------------------------------------------------
-- 12.1.5 source (Gethe/wow-ui-source 297d7aa, read as data): every menu frame comes from a pool and is handed to addons only as a proxy
-- (Blizzard_Menu/Menu.lua:2094-2135). When Blizzard builds a menu it mixes the menu's style into the frame and calls its Generate
-- (SecureGenerate, Menu.lua:2094-2097); the default style for menus and context menus is MenuStyle1Mixin (Mainline/MenuVariants.lua:1-7),
-- whose Generate attaches one background texture with the atlas "common-dropdown-bg" at alpha 0.925 (Mainline/MenuTemplates.lua:51-61).
-- The Esc-menu lesson (GameMenuSkin.lua header, 0.5.37-0.5.40): never restyle pooled parts once and hope; act each time Blizzard builds.
-- So: a post-hook on MenuStyle1Mixin.Generate (placed only when this page is ticked) recolours THAT background texture to the theme's
-- window colour at Background opacity, each time a menu is built. No frame, texture or script is added to Blizzard's menu, nothing is
-- anchored or moved; entries, text and clicks are Blizzard's. Blizzard sets its atlas and alpha again on every build, so with the page
-- off the next menu is Blizzard's own (an open menu keeps the look until it closes). Every call is guarded (pcall): a menu whose regions
-- the game keeps secret is left as it is.
BS.MENU_BG_ATLAS = "common-dropdown-bg"
local liveMenu, hookedMenu = false, false
local function PaintMenu(menu)
    if not liveMenu or type(menu) ~= "table" or type(menu.GetRegions) ~= "function" then return end
    local regions = { menu:GetRegions() }
    local bg = WinBg()
    for _, r in ipairs(regions) do
        local ok, atlas = pcall(function() return r.GetAtlas and r:GetAtlas() end)
        if ok and atlas == BS.MENU_BG_ATLAS then
            r:SetColorTexture(bg[1], bg[2], bg[3], 1)
            r:SetAlpha(Alpha())
            BS.diag.menus = (BS.diag.menus or 0) + 1
            return true
        end
    end
end
BS.PaintMenu = PaintMenu
local function ApplyMenus()
    if PageOn("menus") then
        liveMenu = true
        local mx = rawget(_G, "MenuStyle1Mixin")
        if not hookedMenu and type(mx) == "table" and type(mx.Generate) == "function" then
            hookedMenu = true
            hooksecurefunc(mx, "Generate", function(menu) if liveMenu then Safe(PaintMenu, menu) end end)
        end
    else
        liveMenu = false   -- the hook stays until /reload and does nothing; Blizzard's next build sets its own look
    end
end

-------------------------------------------------------------------------------
-- 7. Chat bubbles (her "chat bubbles")
-------------------------------------------------------------------------------
-- 12.1.5: C_ChatBubbles.GetAllChatBubbles(includeForbidden = false) lists the bubbles on screen (docs/reference/api/namespaces.md:801).
-- Each bubble holds one child built from ChatBubbleTemplate (Blizzard_ChatBubble/ChatBubbleTemplates.xml:3-13, read as data): a
-- NineSlicePanel (SetCenterColor / SetBorderColor, Blizzard_SharedXML/NineSlice.lua:258-283) with a String and a Tail. The game makes no
-- event when a bubble appears, so after each chat message that can show one (say, yell, NPC say / yell / party, party) the bubbles are
-- read on the next frame and any not yet painted take the theme's colours (centre and tail: window colour at Background opacity; border:
-- border colour). The game reuses bubbles, so a painted one keeps the look. Bubbles in dungeons, raids and other instances are forbidden
-- to addons (includeForbidden stays false): they stay Blizzard's. The text and its colour are Blizzard's.
BS.BUBBLE_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_PARTY", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }
local liveBubble, bubbleFrame, bubbleQueued = false, nil, false
local bubbles = setmetatable({}, { __mode = "k" })   -- [bubble's panel] = true while it carries the look
local panelOf = setmetatable({}, { __mode = "k" })   -- [bubble] = its ChatBubbleTemplate child, found once (the game reuses bubbles)
local function BubblePanel(bubble)
    local p = panelOf[bubble]
    if p then return p end
    if type(bubble) ~= "table" or type(bubble.GetChildren) ~= "function" then return end
    for _, c in ipairs({ bubble:GetChildren() }) do
        if type(c) == "table" and type(c.SetCenterColor) == "function" and c.String then panelOf[bubble] = c; return c end
    end
end
local function near(a, b) return num(a) and num(b) and math.abs(a - b) < 0.002 end
-- (perf, hub review 13:26 UTC) a bubble that already shows these exact colours is skipped: the scan runs after each chat message (party
-- chat too), so most scans only read one colour per bubble. The colours are compared, not just remembered, so a theme or opacity change,
-- or the game resetting a reused bubble (INFERENCE: not seen in the source), still repaints it.
local function PaintBubble(bubble)
    local p = BubblePanel(bubble)
    if not p then return end
    local m = M(p)
    local bg, bd, a = WinBg(), WinBorder(), Alpha()
    if bubbles[p] and m.nine and p.GetCenterColor then
        local r, g, b, ca = p:GetCenterColor()
        local pb = m.paintedBorder
        if near(r, bg[1]) and near(g, bg[2]) and near(b, bg[3]) and near(ca, a)
            and pb and pb[1] == bd[1] and pb[2] == bd[2] and pb[3] == bd[3] and pb[4] == (bd[4] or 1) then
            BS.diag.bubbleSkips = (BS.diag.bubbleSkips or 0) + 1
            return
        end
    end
    if not m.nine then
        local cr, cg, cb, ca, br, bgr, bb, ba
        if p.GetCenterColor then cr, cg, cb, ca = p:GetCenterColor() end
        if p.GetBorderColor then br, bgr, bb, ba = p:GetBorderColor() end
        local tr, tg, tb, ta
        if p.Tail and p.Tail.GetVertexColor then tr, tg, tb, ta = p.Tail:GetVertexColor() end
        local function n(v) return num(v) and v or 1 end
        m.nine = { n(cr), n(cg), n(cb), n(ca), n(br), n(bgr), n(bb), n(ba), n(tr), n(tg), n(tb), n(ta) }
    end
    p:SetCenterColor(bg[1], bg[2], bg[3], a)
    if p.SetBorderColor then p:SetBorderColor(bd[1], bd[2], bd[3], bd[4] or 1) end
    if p.Tail and p.Tail.SetVertexColor then p.Tail:SetVertexColor(bg[1], bg[2], bg[3], a) end
    m.paintedBorder = { bd[1], bd[2], bd[3], bd[4] or 1 }
    m.painted = true
    bubbles[p] = true
    BS.diag.bubbles = (BS.diag.bubbles or 0) + 1
end
BS.PaintBubble = PaintBubble
local function UnpaintBubble(p)
    local m = memo[p]
    local c = m and m.nine
    if c then
        pcall(p.SetCenterColor, p, c[1], c[2], c[3], c[4])
        if p.SetBorderColor then pcall(p.SetBorderColor, p, c[5], c[6], c[7], c[8]) end
        if p.Tail and p.Tail.SetVertexColor then pcall(p.Tail.SetVertexColor, p.Tail, c[9], c[10], c[11], c[12]) end
        m.nine, m.painted, m.paintedBorder = nil, nil, nil
    end
    bubbles[p] = nil
end
local function ScanBubbles()
    bubbleQueued = false
    if not liveBubble then return end
    local api = rawget(_G, "C_ChatBubbles")
    if not (api and api.GetAllChatBubbles) then return end
    local ok, list = pcall(api.GetAllChatBubbles, false)
    if not (ok and type(list) == "table") then return end
    for _, b in ipairs(list) do Safe(PaintBubble, b) end
end
BS.ScanBubbles = ScanBubbles
local function ApplyBubbles()
    if PageOn("bubbles") then
        liveBubble = true
        if not bubbleFrame then
            bubbleFrame = CreateFrame("Frame")
            bubbleFrame:SetScript("OnEvent", function()
                if liveBubble and not bubbleQueued then bubbleQueued = true; C_Timer.After(0, ScanBubbles) end
            end)
        end
        for _, ev in ipairs(BS.BUBBLE_EVENTS) do bubbleFrame:RegisterEvent(ev) end
        ScanBubbles()
    elseif liveBubble then
        liveBubble = false
        if bubbleFrame then bubbleFrame:UnregisterAllEvents() end
        for p in pairs(bubbles) do UnpaintBubble(p) end
    end
end

-------------------------------------------------------------------------------
-- 8. Status bars: experience / reputation / honor bars (her "toolbars", Q6 "all")
-------------------------------------------------------------------------------
-- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data): MainStatusTrackingBarContainer and SecondaryStatusTrackingBarContainer
-- (Blizzard_ActionBar/Mainline/StatusTrackingBar.xml:41, 49) come from StatusTrackingBarContainerTemplate (:3-8), whose only art is
-- the OVERLAY texture BarFrameTexture (atlas UI-HUD-ExperienceBar-Frame, set in XML only; no Lua sets it again). That frame art is
-- faded and our background and 1 px border are drawn, as on a window. The bar's fill colours (experience, rested, reputation standing,
-- honor ...) and its text are Blizzard's: they carry information. The containers fade in and out on their own; our pieces are their
-- children and follow. Micro menu and bag bar: not skinned (their art is Blizzard's button art itself; question RSK-Q14).
BS.BARS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local liveBars = false
local hookedBar = {}
local function PaintBar(f)
    if type(f) ~= "table" or type(f.CreateTexture) ~= "function" then return end
    if Blocked(f) then Later(function() if liveBars then PaintBar(f) end end); return end
    Fade(f, f.BarFrameTexture)
    local m = OwnBg(f)
    m.painted = true
    BS.diag.painted = BS.diag.painted + 1
end
BS.PaintBar = PaintBar
local function ApplyBars()
    if PageOn("statusbars") then
        liveBars = true
        for _, n in ipairs(BS.BARS) do
            local f = rawget(_G, n)
            if type(f) == "table" then
                if not hookedBar[f] and type(f.HookScript) == "function" then
                    hookedBar[f] = true
                    f:HookScript("OnShow", function(self) if liveBars then Safe(PaintBar, self) end end)
                end
                Safe(PaintBar, f)
            end
        end
    elseif liveBars then
        liveBars = false
        for _, n in ipairs(BS.BARS) do local f = rawget(_G, n); if f then Restore(f) end end
    end
end

-------------------------------------------------------------------------------
-- 9. Minimap buttons: the zone bar and the tracking button (her "tracking button and options", "minimap calendar button", "mail button")
-------------------------------------------------------------------------------
-- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data, Blizzard_Minimap/Mainline/Minimap.xml): MinimapCluster.BorderTop (:18-27, the bar
-- behind the zone name) is a NineSliceCodeTemplate (NineSlicePanelMixin: Set/GetCenterColor, Set/GetBorderColor) with the texture kit
-- "ui-hud-minimap-button"; MinimapCluster.Tracking.Background (:51-58) is the same kit's round button behind the tracking icon. Both take
-- the theme's colours as a tint (centre / button: window colour; bar border: border colour), the colours they had are read first and given
-- back. The calendar button (GameTimeFrame, GameTime.xml:3) and the mail icon (MiniMapMailIcon, Minimap.xml:99) have no frame art of their
-- own (the day number and envelope are their atlases): they are left as they are (question RSK-Q14). The tracking menu is a Blizzard menu
-- (the Menus page skins it).
local liveMMB = false
local MMBKEY = "minimapbuttons"
local function PaintMinimapButtons()
    local mc = rawget(_G, "MinimapCluster")
    if type(mc) ~= "table" then return end
    local m = M(MMBKEY)
    local bg, bd, a = WinBg(), WinBorder(), Alpha()
    local bar = mc.BorderTop
    if type(bar) == "table" and type(bar.SetCenterColor) == "function" then
        if not m.bar then
            local cr, cg, cb, ca, br, bgr, bb, ba
            if bar.GetCenterColor then cr, cg, cb, ca = bar:GetCenterColor() end
            if bar.GetBorderColor then br, bgr, bb, ba = bar:GetBorderColor() end
            local function n(v) return num(v) and v or 1 end
            m.bar = { n(cr), n(cg), n(cb), n(ca), n(br), n(bgr), n(bb), n(ba) }
        end
        bar:SetCenterColor(bg[1], bg[2], bg[3], a)
        if bar.SetBorderColor then bar:SetBorderColor(bd[1], bd[2], bd[3], bd[4] or 1) end
    end
    local tb = type(mc.Tracking) == "table" and mc.Tracking.Background
    if type(tb) == "table" and type(tb.SetVertexColor) == "function" then
        if not m.track then
            local r, g, b, aa
            if tb.GetVertexColor then r, g, b, aa = tb:GetVertexColor() end
            local function n(v) return num(v) and v or 1 end
            m.track = { n(r), n(g), n(b), n(aa) }
        end
        tb:SetVertexColor(bg[1], bg[2], bg[3], a)
    end
    m.painted = true
end
BS.PaintMinimapButtons = PaintMinimapButtons
local function UnpaintMinimapButtons()
    local m = memo[MMBKEY]
    local mc = rawget(_G, "MinimapCluster")
    if not (m and type(mc) == "table") then return end
    local bar, c = mc.BorderTop, m.bar
    if c and type(bar) == "table" then
        pcall(bar.SetCenterColor, bar, c[1], c[2], c[3], c[4])
        if bar.SetBorderColor then pcall(bar.SetBorderColor, bar, c[5], c[6], c[7], c[8]) end
    end
    local tb, t = type(mc.Tracking) == "table" and mc.Tracking.Background, m.track
    if t and type(tb) == "table" then pcall(tb.SetVertexColor, tb, t[1], t[2], t[3], t[4]) end
    m.bar, m.track, m.painted = nil, nil, nil
end
local function ApplyMinimapButtons()
    if PageOn("mmbuttons") then
        liveMMB = true
        Safe(PaintMinimapButtons)
    elseif liveMMB then
        liveMMB = false
        UnpaintMinimapButtons()
    end
end

-------------------------------------------------------------------------------
-- 10. Buttons: Blizzard's red panel buttons inside the windows of the Blizzard Windows list (her Q10 "everything", plan section 4)
-------------------------------------------------------------------------------
-- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data): UIPanelButtonNoTooltipTemplate (Blizzard_SharedXML/SecureUIPanelTemplates.xml:39-80)
-- draws a red button from three BACKGROUND textures Left / Middle / Right; its scripts swap their texture for pressed / disabled
-- (SecureUIPanelTemplates.lua:44-80), which does not change their alpha. Those three are faded and XayaUI's flat button look is drawn
-- under them: a background and 1 px border in the theme's xui-button colours (the look XayaUI's own windows use, Core.lua
-- ns.PaintFlatButton). The text, its gold / white / grey states, the hover highlight and what a click does stay Blizzard's.
-- Only buttons inside the windows of BS.WINDOWS are touched (found by walking the window's children each time it is shown), never other
-- addons' windows (question RSK-Q1: shared templates). Close buttons, scroll bars, tabs and dropdown arrows are not restyled (they would
-- need new art; question RSK-Q15). A protected button is never painted in combat (it waits for combat to end).
local liveBtn = false
local hookedBtnWin = {}
local btnPainted = setmetatable({}, { __mode = "k" })
local function BtnBg() return TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 }) end
local function BtnBorder() return TC("xui-button", "border", { 0.25, 0.25, 0.25, 1 }) end
local function IsPanelButton(b)
    if type(b) ~= "table" or type(b.GetObjectType) ~= "function" then return false end
    local ok, t = pcall(b.GetObjectType, b)
    if not (ok and t == "Button") then return false end
    return type(b.Left) == "table" and type(b.Middle) == "table" and type(b.Right) == "table" and type(b.Left.SetAlpha) == "function"
end
BS.IsPanelButton = IsPanelButton
local function PaintButton(b)
    if Blocked(b) then Later(function() if liveBtn then PaintButton(b) end end); return end
    Fade(b, b.Left); Fade(b, b.Middle); Fade(b, b.Right)
    local m = M(b)
    if not m.bg then
        m.bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
        m.bg:SetAllPoints(b)
        m.own[#m.own + 1] = m.bg
    end
    local c = BtnBg()
    m.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1); m.bg:Show()
    PaintEdges(Edges(b, b), BtnBorder())
    m.painted = true
    btnPainted[b] = true
end
BS.PaintButton = PaintButton
local function WalkButtons(f, depth)
    if type(f) ~= "table" or type(f.GetChildren) ~= "function" or depth > 8 then return end
    for _, c in ipairs({ f:GetChildren() }) do
        if IsPanelButton(c) then Safe(PaintButton, c) end
        WalkButtons(c, depth + 1)
    end
end
BS.WalkButtons = WalkButtons
local btnLodFrame, btnLodOn = nil, false
local function HookBtnWindow(name)
    local f = rawget(_G, name)
    if type(f) ~= "table" then return false end
    if not hookedBtnWin[f] and type(f.HookScript) == "function" then
        hookedBtnWin[f] = true
        f:HookScript("OnShow", function(self) if liveBtn then WalkButtons(self, 1) end end)
    end
    if liveBtn then WalkButtons(f, 1) end
    return true
end
local function BtnWatchLoad(on)
    if on and not btnLodFrame then
        btnLodFrame = CreateFrame("Frame")
        btnLodFrame:SetScript("OnEvent", function(_, _, name)
            if not liveBtn then return end
            for _, e in ipairs(BS.WINDOWS) do if e.lod == name then for _, n in ipairs(e.frames) do HookBtnWindow(n) end end end
        end)
    end
    if btnLodFrame then if on then btnLodFrame:RegisterEvent("ADDON_LOADED") else btnLodFrame:UnregisterEvent("ADDON_LOADED") end end
    btnLodOn = (on and btnLodFrame) and true or false
end
local function ApplyButtons()
    if PageOn("buttons") then
        liveBtn = true
        local needLoad = false
        for _, e in ipairs(BS.WINDOWS) do
            for _, n in ipairs(e.frames) do if not HookBtnWindow(n) and e.lod then needLoad = true end end
        end
        BtnWatchLoad(needLoad)
    elseif liveBtn then
        liveBtn = false
        BtnWatchLoad(false)
        for b in pairs(btnPainted) do Restore(b); btnPainted[b] = nil end
    end
end

-------------------------------------------------------------------------------
-- On / off: each page's tick box and the Blizzard Reskin tab's own switch call this
-------------------------------------------------------------------------------
function BS.Apply()
    Safe(ApplyWindows); Safe(ApplyMinimap); Safe(ApplyTooltips); Safe(ApplyTracker); Safe(ApplyToasts); Safe(ApplyMenus); Safe(ApplyBubbles); Safe(ApplyBars); Safe(ApplyMinimapButtons); Safe(ApplyButtons)
end
function BS.Live() return { windows = liveWin, minimap = liveMap, tooltips = liveTip, tracker = liveOT, toasts = liveToast, menus = liveMenu, bubbles = liveBubble, bubbleEvents = bubbleFrame ~= nil and liveBubble, statusbars = liveBars, mmbuttons = liveMMB, buttons = liveBtn, buttonsLodWatch = btnLodOn, lodWatch = lodOn, waitFrame = waitFrame ~= nil } end
ns.RegisterReskin("blizzardskins", BS.Apply)
ns.Provide("blizzardSkins", { Apply = BS.Apply, Live = BS.Live, Saved = Saved, Cfg = Cfg, PageOn = PageOn, WinOn = WinOn, SecOn = SecOn,
    WINDOWS = BS.WINDOWS, SECTIONS = BS.SECTIONS, TOASTS = BS.TOASTS, ToastOn = ToastOn, MENU_BG_ATLAS = BS.MENU_BG_ATLAS, BUBBLE_EVENTS = BS.BUBBLE_EVENTS, BARS = BS.BARS, IsPanelButton = IsPanelButton, SectionLabel = BS.SectionLabel, memo = memo, diag = BS.diag, OurShape = OurShape,
    SQUARE_MASK = BS.SQUARE_MASK, ROUND_MASK = BS.ROUND_MASK })
-- at login, only when something is ticked (a saved table with a page on); nothing is made otherwise
ns.WhenReady(function()
    local r = Saved()
    if r and (r.windows or r.minimap or r.tooltips or r.tracker or r.toasts or r.menus or r.bubbles or r.statusbars or r.mmbuttons or r.buttons) and TabOn() then
        if ns.AtLogin then ns.AtLogin(BS.Apply) else BS.Apply() end
    end
end)

-------------------------------------------------------------------------------
-- Settings: pages of the Blizzard Reskin tab, each with its own tick box in the left pane (xuiSwitch)
-------------------------------------------------------------------------------
local function re(Notify) BS.Apply(); if Notify then Notify() end end
local function PageSwitch(page, name, tip, desc, Notify)
    return { type = "toggle", name = name, tip = tip, desc = desc,
        get = function() local r = Saved(); return r and r[page] == true or false end,
        set = function(_, v) Cfg()[page] = v and true or nil; re(Notify) end,
        disabled = function() return not TabOn() end }
end
local OFFNOTE = " Off: nothing of it is made or runs. Switched off after it was on, Blizzard's look comes back at once; its hooks stay until you /reload but do nothing. Greyed while Blizzard Reskin is off (this tab's Overview)."

function BS.WindowsPage(Notify)
    local off = function() return not PageOn("windows") end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "XayaUI's look on Blizzard's windows: a solid background in the theme's window color, a thin border and the theme's title color, in place of Blizzard's frame art. Nothing in a window moves or changes size. Windows Blizzard loads later (spellbook, professions, auction house ...) take the look when they first open." },
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
            name = "The minimap's shape. Square: a square map with a thin border in the theme's color (it shows a little more ground in its corners). Circle: Blizzard's own round minimap." },
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
            name = "Tooltips (the HUD tooltip, item links and item comparisons) take the theme's window color and border color. What a tooltip says is unchanged; its opacity is Blizzard Windows' Background opacity." },
    }
    return { type = "group", name = "Tooltips", order = 6, args = args,
        xuiSwitch = PageSwitch("tooltips", "Use the XayaUI look on tooltips", "Tooltips in the theme's colors.", "Colors tooltips in the theme." .. OFFNOTE, Notify) }
end

function BS.TrackerPage(Notify)
    local off = function() return not PageOn("tracker") end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "The objective tracker: its header and each section's header in the theme's label color without Blizzard's header art, and each section's quest titles and lines in the theme's text colors (finished lines muted). Nothing moves; what the tracker lists is unchanged." },
        list = { type = "group", order = 10, inline = true, name = "Sections (untick one to leave it as Blizzard draws it)", args = {} },
    }
    for i, s in ipairs(BS.SECTIONS) do
        local isProf = s.key == "professions"
        args.list.args[s.key] = { type = "toggle", order = i, name = function() return BS.SectionLabel(s) end, disabled = off,
            desc = isProf and "While the Shopping List's tracker part is on (Blizzard Reskin > Shopping List), the Shopping List restyles this section and this box has no effect." or nil,
            get = function() local r = Saved(); return not (r and r.otOff and r.otOff[s.key]) end,
            set = function(_, v) Cfg().otOff[s.key] = (not v) and true or nil; re(Notify) end }
    end
    return { type = "group", name = "Objective Tracker", order = 7, args = args,
        xuiSwitch = PageSwitch("tracker", "Use the XayaUI look on the objective tracker", "The objective tracker in the theme's colors.",
            "Restyles the objective tracker; each section has its own box on this page." .. OFFNOTE, Notify) }
end

function BS.ToastsPage(Notify)
    local off = function() return not PageOn("toasts") end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Battle.net toasts (the box that slides in when a friend comes online) and Blizzard's pop-up dialogs take the theme's window color and a thin border in the theme's border color, in place of Blizzard's art. What they say, their buttons and where they appear are unchanged. Opacity: Blizzard Windows' Background opacity." },
        list = { type = "group", order = 10, inline = true, name = "Parts (untick one to leave it as Blizzard draws it)", args = {} },
    }
    for i, e in ipairs(BS.TOASTS) do
        args.list.args[e.key] = { type = "toggle", order = i, name = e.label, disabled = off,
            get = function() local r = Saved(); return not (r and r.toastOff and r.toastOff[e.key]) end,
            set = function(_, v) Cfg().toastOff[e.key] = (not v) and true or nil; re(Notify) end }
    end
    return { type = "group", name = "Toasts and Pop-ups", order = 8, args = args,
        xuiSwitch = PageSwitch("toasts", "Use the XayaUI look on toasts and pop-ups", "Battle.net toasts and pop-up dialogs in the theme's colors.",
            "Restyles Battle.net toasts and Blizzard's pop-up dialogs; each has its own box on this page." .. OFFNOTE, Notify) }
end

function BS.MenusPage(Notify)
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Blizzard's right-click menus and dropdown lists take the theme's window color in place of Blizzard's menu background, each time a menu opens. The entries, their text, checks and what a click does are unchanged. Opacity: Blizzard Windows' Background opacity. A menu that is open when you untick this keeps the look until it closes." },
    }
    return { type = "group", name = "Menus", order = 9, args = args,
        xuiSwitch = PageSwitch("menus", "Use the XayaUI look on menus", "Right-click and dropdown menus in the theme's color.",
            "Recolors Blizzard's right-click and dropdown menus." .. OFFNOTE, Notify) }
end

function BS.BubblesPage(Notify)
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Chat bubbles over players and NPCs take the theme's window color (with their tail) and border color. What they say and its color are unchanged. Opacity: Blizzard Windows' Background opacity. In dungeons, raids and other instances the game does not let addons change chat bubbles: there they stay Blizzard's." },
    }
    return { type = "group", name = "Chat Bubbles", order = 10, args = args,
        xuiSwitch = PageSwitch("bubbles", "Use the XayaUI look on chat bubbles", "Chat bubbles in the theme's colors.",
            "Colors chat bubbles in the theme (outside instances)." .. OFFNOTE, Notify) }
end

function BS.StatusBarsPage(Notify)
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "The experience, reputation and honor bars at the bottom of the screen: Blizzard's frame art around them is replaced by a background in the theme's window color and a thin border. The bars' fill colors, their text and where they sit (Edit Mode) are unchanged. Opacity: Blizzard Windows' Background opacity." },
    }
    return { type = "group", name = "Status Bars", order = 11, args = args,
        xuiSwitch = PageSwitch("statusbars", "Use the XayaUI look on the status bars", "Experience / reputation bars in the theme's colors.",
            "Restyles the frame of the experience, reputation and honor bars." .. OFFNOTE, Notify) }
end

function BS.MinimapButtonsPage(Notify)
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "The bar behind the zone name above the minimap and the round button behind the tracking icon take the theme's colors. The icons, the zone name and what each button does are unchanged. The calendar button and the mail icon have no frame of their own and stay as they are; the tracking menu follows the Menus page. Opacity: Blizzard Windows' Background opacity." },
    }
    return { type = "group", name = "Minimap Buttons", order = 12, args = args,
        xuiSwitch = PageSwitch("mmbuttons", "Use the XayaUI look on the minimap buttons", "The zone bar and tracking button in the theme's colors.",
            "Colors the minimap's zone bar and tracking button in the theme." .. OFFNOTE, Notify) }
end

function BS.ButtonsPage(Notify)
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "The red buttons inside Blizzard's windows (the windows listed on the Blizzard Windows page: Mail's Send, the Auction House's Buy, Talents' Apply ...) take XayaUI's flat button look: a background and thin border in the theme's button colors instead of Blizzard's red art. Their text, its color when a button is greyed out, the hover glow and what a click does are unchanged. Buttons in other addons' windows are not touched. Close buttons, scroll bars, tabs and dropdown arrows keep Blizzard's look." },
    }
    return { type = "group", name = "Buttons", order = 13, args = args,
        xuiSwitch = PageSwitch("buttons", "Use the XayaUI look on buttons in Blizzard's windows", "Blizzard's red buttons in XayaUI's flat look.",
            "Restyles the red buttons inside Blizzard's windows." .. OFFNOTE, Notify) }
end

ns.RegisterSettingsPage("reskin", "blizzwindows", BS.WindowsPage)
ns.RegisterSettingsPage("reskin", "minimapshape", BS.MinimapPage)
ns.RegisterSettingsPage("reskin", "rsktooltips", BS.TooltipsPage)   -- (not "tooltips": page keys are unique across tabs, and Bonus Features owns that one)
ns.RegisterSettingsPage("reskin", "objtracker", BS.TrackerPage)
ns.RegisterSettingsPage("reskin", "rsktoasts", BS.ToastsPage)
ns.RegisterSettingsPage("reskin", "rskmenus", BS.MenusPage)
ns.RegisterSettingsPage("reskin", "rskbubbles", BS.BubblesPage)
ns.RegisterSettingsPage("reskin", "rskstatusbars", BS.StatusBarsPage)
ns.RegisterSettingsPage("reskin", "rskmmbuttons", BS.MinimapButtonsPage)
ns.RegisterSettingsPage("reskin", "rskbuttons", BS.ButtonsPage)
