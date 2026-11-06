-------------------------------------------------------------------------------
-- Modules.lua : the contract between XayaUI core and the features that plug into it (0.5.108).
--
-- XayaUI is being split into separate addons that can each be switched on or off in the game's AddOns list:
--   XayaUI          core: rules, the combat aura engine, profiles, theme, console, minimap button, ESC-menu button
--   XayaUI_Chat     every chat change and feature
--   XayaUI_QoL      cursor changes (friends and bags later)
--   XayaUI_Bonus    enhanced tooltips, notepad, custom data panels
--   XayaUI_Reskin   Blizzard frames restyled without changing what they do
--   XayaUI_Options  the settings window, loaded the first time it opens
-- Core never calls a feature by name. A feature registers what it offers here, and core only walks these lists, so a feature
-- that is switched off (or not installed) simply leaves nothing behind:
--   ns.WhenReady(fn)                          run fn once the saved settings exist (right away if they already do)
--   ns.RegisterCommand(names, fn, help)       /xui <name> [args]; names is one string or a list; several handlers may share a name
--   ns.RegisterLauncher(entry)                a row in the minimap button's quick-access list
--   ns.RegisterSettingsPage(module, key, fn)  a page in the settings window; fn(Notify) returns an AceConfig group
--   ns.RegisterReskin(key, apply)             a reskin of the Blizzard UI Reskin tab; apply() takes the tab's switch (core 0.6.51)
--   ns.MODULES                                which addon owns which /xui commands, so core can say why one does nothing
-- Every registered function is called through pcall: one feature's error never stops the next one from starting.
-- Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local _, ns = ...

local function Report(err)
    local h = geterrorhandler and geterrorhandler()
    if h then h(err) end
end
local function Call(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Report(err) end
    return ok
end

-- 0. Spacing every XayaUI window and pane uses (#351; Xaya, 2026-11-03: "set a standard gutter and margin so that all elements are
-- not smushed directly into their container bounds"). UI_MARGIN: the least space between a container's edge (below its title row)
-- and what is inside it. UI_GUTTER: the least space between two controls side by side. Defined here once, in core, so every addon
-- has them (each one depends on XayaUI). Windows that already leave more room keep it; segmented rows (tabs, filter buttons, icon
-- toolbars) keep their 2 px seams; title-bar close buttons and corner resize grips sit at the edge, as in Blizzard's windows.
ns.UI_MARGIN, ns.UI_GUTTER = 10, 10

-------------------------------------------------------------------------------
-- 1. Saved settings ready. Core.lua calls ns.FireReady() once, at XayaUI's own ADDON_LOADED, right after the saved settings are set
-- up. Anything registered before that waits in the queue (in load order); anything registered after (a sibling addon loads later
-- than XayaUI) runs at once.
-------------------------------------------------------------------------------
local readyQueue, isReady = {}, false

function ns.WhenReady(fn)
    if type(fn) ~= "function" then return end
    if isReady then Call(fn) else readyQueue[#readyQueue + 1] = fn end
end

function ns.FireReady()
    if isReady then return end
    isReady = true
    local queue = readyQueue
    readyQueue = {}
    for _, fn in ipairs(queue) do Call(fn) end
end

function ns.IsReady() return isReady end

-- 1b. Logged in (core 0.6.47). Core.lua's own start-up frame calls ns.FireLogin() once, at PLAYER_LOGIN. ns.AtLogin(fn) runs fn then, or
-- at once when it already fired. For features that must wait for the login (the game menu, other addons' services) but are switched
-- on only now and then: they ask for it only when they are on, so a feature that is off needs no frame or event of its own (V14).
local loginQueue, loggedIn = {}, false
function ns.AtLogin(fn)
    if type(fn) ~= "function" then return end
    if loggedIn then Call(fn) else loginQueue[#loginQueue + 1] = fn end
end
function ns.FireLogin()
    if loggedIn then return end
    loggedIn = true
    local queue = loginQueue
    loginQueue = {}
    for _, fn in ipairs(queue) do Call(fn) end
end
function ns.LoggedIn() return loggedIn end

-------------------------------------------------------------------------------
-- 2. /xui commands. Core's own commands stay in Core.lua; a feature adds its own here.
-------------------------------------------------------------------------------
local commands, helpText = {}, {}

function ns.RegisterCommand(names, fn, help)
    if type(fn) ~= "function" then return end
    if type(names) == "string" then names = { names } end
    for _, n in ipairs(names) do
        n = tostring(n):lower()
        commands[n] = commands[n] or {}
        table.insert(commands[n], fn)
    end
    if type(help) == "string" and help ~= "" then helpText[#helpText + 1] = help end
end

-- true when at least one registered handler took the command
function ns.RunCommand(cmd, arg)
    local list = commands[cmd]
    if not list then return false end
    for _, fn in ipairs(list) do Call(fn, arg) end
    return true
end

function ns.CommandHelp() return helpText end

-------------------------------------------------------------------------------
-- 3. Which addon owns what. Only used for messages and the Addon Info status list; nothing here is called.
-------------------------------------------------------------------------------
ns.MODULES = {
    { addon = "XayaUI_Chat",    title = "XayaUI Chat",            commands = { "chat", "panel", "chatprobe", "privacy" } },
    { addon = "XayaUI_QoL",     title = "XayaUI QoL",             commands = { "cursor" } },
    { addon = "XayaUI_Bonus",   title = "XayaUI Bonus Features",  commands = { "notes", "notepad", "note", "data" } },
    { addon = "XayaUI_Reskin",  title = "XayaUI Blizzard Reskin", commands = {} },
    { addon = "XayaUI_Options", title = "XayaUI Options",         commands = {} },
}

function ns.ModuleOfCommand(cmd)
    for _, m in ipairs(ns.MODULES) do
        for _, c in ipairs(m.commands) do if c == cmd then return m end end
    end
end

-- "loaded", "disabled", "missing", or "unknown" (game API not available). Wrapped: C_AddOns can refuse odd names.
function ns.ModuleState(addon)
    local A = C_AddOns
    if not A then return "unknown" end
    local okL, loaded = pcall(A.IsAddOnLoaded, addon)
    if okL and loaded then return "loaded" end
    local okI, name, _, _, _, reason = pcall(A.GetAddOnInfo, addon)
    if not okI then return "unknown" end
    if reason == "MISSING" or not name then return "missing" end
    return "disabled"
end

-- One line explaining why a command did nothing. Until a feature has moved out of the XayaUI folder its addon does not exist yet,
-- so "missing" there means the feature's own file failed to load.
function ns.ModuleMissingText(cmd)
    local m = ns.ModuleOfCommand(cmd)
    if not m then return nil end
    local state = ns.ModuleState(m.addon)
    if state == "disabled" then
        return ("/xui %s is part of %s, which is switched off. Turn it on in the game's AddOns list, then /reload."):format(cmd, m.title)
    elseif state == "missing" then
        return ("/xui %s is part of %s, which is not installed (or its files failed to load; /xui bug shows errors)."):format(cmd, m.title)
    end
    return ("/xui %s did not respond: %s is loaded, but the command was never registered. /xui bug shows errors."):format(cmd, m.title)
end

-------------------------------------------------------------------------------
-- 4. Minimap button list. entry = { key, label, tooltip, action, stateFn (optional), order = number, available = fn (optional) }
-- Positional fields keep MinimapButton.lua's row code unchanged. Lower order is higher in the list.
-- available (core 0.6.49): a function that returns false while the entry's feature is switched off; the list then leaves the row out
-- (V14: a switched-off feature shows no row; first user: the Character Toolkit's Stat Calculator row, QoL 0.7.23). The entry stays
-- registered, so the settings window's options tree is the same with the feature on and off (a sidebar tick reuses the drawn tree,
-- tests/sidebar_switches_run.py); its row on Settings > Minimap Button is hidden instead.
-------------------------------------------------------------------------------
local launchers = {}

function ns.RegisterLauncher(entry)
    if type(entry) ~= "table" or type(entry[1]) ~= "string" or type(entry[4]) ~= "function" then return end
    for i, e in ipairs(launchers) do
        if e[1] == entry[1] then launchers[i] = entry; return end   -- same key again (a second copy of a file): replace, never duplicate
    end
    launchers[#launchers + 1] = entry
    table.sort(launchers, function(a, b)
        local oa, ob = tonumber(a.order) or 100, tonumber(b.order) or 100
        if oa ~= ob then return oa < ob end
        return a[1] < b[1]
    end)
end

function ns.Launchers() return launchers end

-------------------------------------------------------------------------------
-- 5. Settings pages. module = "chat", "qol", "bonus", "reskin" (which tab the page belongs to), key = the page's key inside it.
-- The settings window calls build(Notify) every time it rebuilds its tree.
-------------------------------------------------------------------------------
local pages = {}

function ns.RegisterSettingsPage(module, key, build)
    if type(key) ~= "string" or type(build) ~= "function" then return end
    for i, p in ipairs(pages) do
        if p.key == key then pages[i] = { module = module, key = key, build = build }; return end
    end
    pages[#pages + 1] = { module = module, key = key, build = build }
end

-- The Blizzard UI Reskin tab's own switch (core 0.6.51, S1 #48; Xaya 2026-11-05: "double: both enable/disable of reskin at all; then individual
-- toggles for individual reskins"). Off turns every reskin off (Chat Panel, Character Pane, Esc Menu, Shopping List) and each keeps its
-- own switch for when the tab is on again. Saved only while off (CueRulesDB.reskinTabOff = true), so a profile that never touched it
-- holds nothing. Every reskin reads it with its own switch: on = its own switch AND this one.
function ns.ReskinTabOn() return not (type(CueRulesDB) == "table" and CueRulesDB.reskinTabOff) end
-- Each reskin registers its own apply (it builds, or gives Blizzard's look back) with ns.RegisterReskin(key, fn), the way features
-- register everything else here; core only walks the list. A reskin whose addon is off is simply not in it.
local reskins = {}
function ns.RegisterReskin(key, apply) if type(key) == "string" and type(apply) == "function" then reskins[key] = apply end end
-- Set it and let every registered reskin take it at once (in key order, each through pcall).
function ns.SetReskinTab(on)
    if type(CueRulesDB) ~= "table" then return end
    CueRulesDB.reskinTabOff = (not on) and true or nil
    local keys = {}
    for k in pairs(reskins) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do Call(reskins[k]) end
end

-- Page layout for every feature tab (Xaya, 2026-11-03; QoL and Chat first, the rule for new features):
--   * a feature is a node in the left pane; its parts are child nodes under it (the feature's group has childGroups = "tree"),
--     and the feature's own node shows its overview (on/off switches, a short note);
--   * inside one part, its sections are tabs.
-- ns.SectionTabs(group) gives a part that shape from a flat list: everything before the first header stays above the tabs, and
-- each header becomes a tab holding the entries up to the next header. The header's desc becomes the tab's first line and its
-- hidden carries over. The group is changed in place and returned; a group without headers is returned unchanged.
function ns.SectionTabs(group)
    local args = type(group) == "table" and group.args
    if type(args) ~= "table" then return group end
    local function ord(e)
        local o = e.order
        if type(o) == "function" then local ok, v = pcall(o); o = ok and v or nil end
        return tonumber(o) or 100
    end
    local heads = {}
    for k, e in pairs(args) do
        if type(e) == "table" and e.type == "header" then heads[#heads + 1] = { key = k, e = e, o = ord(e) } end
    end
    if #heads == 0 then return group end
    table.sort(heads, function(a, b) if a.o ~= b.o then return a.o < b.o end return tostring(a.key) < tostring(b.key) end)
    local tabs = {}
    for i, h in ipairs(heads) do
        tabs[i] = { type = "group", name = h.e.name, order = h.o, hidden = h.e.hidden, args = {} }
        if h.e.desc ~= nil and h.e.desc ~= "" then
            tabs[i].args.sectionNote = { type = "description", order = h.o - 0.001, width = "full", fontSize = "medium", name = h.e.desc }
        end
    end
    local moves = {}
    for k, e in pairs(args) do
        if type(e) == "table" and e.type ~= "header" then
            local o, at = ord(e), nil
            for i = #heads, 1, -1 do if heads[i].o <= o then at = i; break end end
            if at then moves[#moves + 1] = { k = k, at = at } end
        end
    end
    for _, m in ipairs(moves) do
        local dest = tabs[m.at].args
        local key = (m.k == "sectionNote") and "sectionNote2" or m.k
        dest[key] = args[m.k]; args[m.k] = nil
    end
    for i, h in ipairs(heads) do
        args[h.key] = nil
        args["tab_" .. tostring(h.key)] = tabs[i]
    end
    group.childGroups = "tab"
    return group
end

-- { [key] = group } for every page of one module (or of all modules when module is nil). A page whose builder errors is skipped.
function ns.BuildSettingsPages(module, Notify)
    local out = {}
    for _, p in ipairs(pages) do
        if module == nil or p.module == module then
            local ok, group = pcall(p.build, Notify)
            if ok and type(group) == "table" then out[p.key] = group elseif not ok then Report(group) end
        end
    end
    return out
end

-------------------------------------------------------------------------------
-- 6. Messages between XayaUI's own parts (not game events). The sender never needs the receiver to exist: the settings window
-- is in a load-on-demand addon and may never be loaded in a session.
--   CONFIG_CHANGED (what)  settings or rules changed outside the window (a drag on screen, a command, an import): redraw if open.
--                    what = "view": only a switch's state changed (nothing in the options tree), so the redraw may reuse the tree
--   LOG (line)       a line for the debug console
--   THEME_CHANGED    the theme changed: re-skin open windows
--   EDITED           ns.MarkDirty ran (the window's undo journal listens)
-------------------------------------------------------------------------------
local listeners = {}
function ns.On(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then return end
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end
function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for _, fn in ipairs(list) do Call(fn, ...) end
end

-------------------------------------------------------------------------------
-- 7. The settings window. Its code is the addon XayaUI_Options, which the game loads only when asked (## LoadOnDemand). Everything
-- outside it opens the window through these functions, so nothing else needs to know whether it is loaded yet. XayaUI_Options
-- fills in ns.Options = { Toggle, EditRule, OpenPage, IconReport, IsOpen, SkinOn } when it loads.
-------------------------------------------------------------------------------
ns.OPTIONS_ADDON = "XayaUI_Options"
local optionsWarned
function ns.LoadOptions()
    if ns.Options then return true end
    if not isReady then ns.Print("saved settings are not ready yet; try again in a moment."); return false end
    local A = C_AddOns
    if not (A and A.LoadAddOn) then return false end
    local ok, loaded, reason = pcall(A.LoadAddOn, ns.OPTIONS_ADDON)
    if ok and loaded and ns.Options then return true end
    if not optionsWarned then
        optionsWarned = true
        local state = ns.ModuleState(ns.OPTIONS_ADDON)
        if state == "disabled" then
            ns.Print("the settings window (XayaUI Options) is switched off in the game's AddOns list. Turn it on, then /reload.")
        elseif state == "missing" then
            ns.Print("the settings window (XayaUI Options) is not installed: the XayaUI_Options folder belongs next to XayaUI in Interface\\AddOns.")
        else
            ns.Print("the settings window could not load (" .. tostring(ok and reason or loaded) .. "). /xui bug shows errors.")
        end
    end
    return false
end
function ns.ToggleUI() if ns.LoadOptions() then ns.Options.Toggle() end end
function ns.EditRule(rule) if rule and ns.LoadOptions() then ns.Options.EditRule(rule) end end
function ns.EditFolder(f) if f and ns.LoadOptions() and ns.Options.EditFolder then ns.Options.EditFolder(f) end end
-- module = "chat" | "qol" | "bonus" | "reskin" | "core"; key = the page registered with ns.RegisterSettingsPage; sub = a tab inside it
-- ... = the path below the page: a part (left-pane child node) and/or a tab, e.g. ("chat", "chatpanel", "bar", "tab_blocksHdr")
function ns.OpenSettingsPage(module, key, ...) if ns.LoadOptions() then ns.Options.OpenPage(module, key, ...) end end
function ns.IconReport() if ns.LoadOptions() and ns.Options.IconReport then ns.Options.IconReport() end end
function ns.IsOptionsOpen() return ns.Options and ns.Options.IsOpen and ns.Options.IsOpen() or false end

-- The game's own Options > AddOns list gets an entry that opens the real window, and the addon compartment (the minimap "addons"
-- menu) calls XayaUI_OnCompartmentClick (named in XayaUI.toc). Both live here so they work before the window's code is loaded.
local function RegisterBlizzardPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory and CreateFrame) then return end
    local panel = CreateFrame("Frame")
    panel.name = "XayaUI"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("XayaUI")
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetWidth(560)
    sub:SetJustifyH("LEFT")
    sub:SetText("Sound cues and on-screen alerts driven by rules: buff, cooldown, talent, and conditions.\nSlash commands: /xui (or /xayaui)  |  /xui status  |  /xui probe <spellID>  |  /xui unlock")
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(200, 28)
    btn:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -20)
    btn:SetText("Open XayaUI")
    btn:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then
            if ns.MapTrace then ns.MapTrace("core: HideUIPanel(SettingsPanel)") end
            if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
        end
        if not ns.IsOptionsOpen() then ns.ToggleUI() end
    end)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "XayaUI")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        ns.settingsCategory = category
    end
end
Call(RegisterBlizzardPanel)
function XayaUI_OnCompartmentClick() ns.ToggleUI() end

-- /xuiskin [pad N | alpha X]: the settings window's flat look (read by XayaUI_Options when the window opens)
SLASH_XUISKIN1 = "/xuiskin"
if type(SlashCmdList) == "table" then SlashCmdList["XUISKIN"] = function(msg)
    if not CueRulesDB then return end
    CueRulesDB.ui = CueRulesDB.ui or {}
    local pd = tostring(msg or ""):match("pad%s+(%d+)")
    if pd then
        CueRulesDB.ui.skinPad = math.max(0, math.min(30, tonumber(pd)))
        print("|cffffd100XayaUI|r right-pane gutter " .. CueRulesDB.ui.skinPad .. "px (reopen the window to apply).")
        return
    end
    local v = tostring(msg or ""):match("alpha%s+([%d%.]+)")
    if v then
        v = math.max(0.1, math.min(1, tonumber(v) or 0.5))
        CueRulesDB.ui.skinAlpha = v
        print("|cffffd100XayaUI|r window opacity " .. v .. " (reopen the window to apply).")
        return
    end
    CueRulesDB.ui.skinOff = (not CueRulesDB.ui.skinOff) or nil
    print("|cffffd100XayaUI|r window skin " .. (CueRulesDB.ui.skinOff and "OFF" or "ON") .. " - type /reload to apply.")
end
end

-------------------------------------------------------------------------------
-- 8. Services: a feature that answers questions for others registers an object under a name; the asker gets nil when that feature
-- is switched off. Today: "gameMenuSkin" (XayaUI_Reskin) answers Active() and MatchReal() for the ESC-menu button (GameMenu.lua);
-- "buttonSkin" (XayaUI_Options) answers Apply(button, primary), the flat button look core's own windows use (Core.lua ns.FlatButton).
-------------------------------------------------------------------------------
local services = {}
function ns.Provide(name, obj) if type(name) == "string" and type(obj) == "table" then services[name] = obj end end
function ns.Service(name) return services[name] end

-------------------------------------------------------------------------------
-- 9. The world map report: /xui debug map (core 0.6.49; REQUEST-LOG #30, Xaya 2026-11-05: "map eclipses full screen" [the Silvermoon
-- world map full screen], 2026-11-06: it happens "only with XayaUI on"). NOT a fix: the cause was not found offline (debug log of QoL
-- 0.7.24). What decides it in Blizzard's code (12.1.5 source, read 2026-11-06): the map opens maximized (full screen, black around it)
-- when QuestLogOwnerMixin:ShouldBeMinimized() is false: `C_GameRules.IsGameRuleActive(Enum.GameRule.MaximizeWorldMapDisabled) or
-- GetCVarBool("miniWorldMap")` (Blizzard_WorldMap/QuestLogOwnerMixin.lua:194-198); its OnShow maximizes or minimizes to match the CVar
-- (Blizzard_WorldMap.lua:365-372); maximizing calls MaximizeUIPanel and sizes the map from its parent's size (Blizzard_WorldMap.lua:
-- 18-23, 438-455). No XayaUI file sets that CVar or calls a world map function (git grep: SetCVar only for the four volume CVars in
-- Sound.lua). XayaUI's only calls into Blizzard's panel manager are counted here (ns.MapTrace) so the report says which ran since login.
-- API (docs/reference/api): C_CVar.GetCVar(name: cstring) -> value: string? · SecretArguments=NotAllowed (namespaces.md:584);
-- C_GameRules.IsGameRuleActive(gameRule: GameRule) -> isActive: bool · SecretArguments=AllowedWhenUntainted (namespaces.md:1926);
-- Enum.GameRule.MaximizeWorldMapDisabled = 67 (enums.md:5681); GetSize(ignoreRect: bool = false) -> width, height · ConstSecretAccessor,
-- SecretWhenAnchoringSecret; GetEffectiveScale() -> effectiveScale · SecretReturnsForAspect=[Scale]; GetScale(); IsShown() (widgets.md).
-- INFERENCE (Blizzard's Lua, not API documentation): WorldMapFrame:IsMaximized() (Blizzard_WorldMap.lua:117) and GetUIPanel(key)
-- (UIParentPanelManager.lua:918). Every read is pcall'd; a secret or missing answer prints "?". Nothing here runs until typed; the
-- counter is one table write per call it counts.
-------------------------------------------------------------------------------
local mapTrace, mapOrder = {}, {}
function ns.MapTrace(name)
    local t = mapTrace[name]
    if not t then t = { n = 0 }; mapTrace[name] = t; mapOrder[#mapOrder + 1] = name end
    t.n = t.n + 1
    t.last = GetTime and GetTime() or 0
end
function ns.MapTraceCounts() return mapTrace end   -- (tests)
local function MapLines()
    local function S(v)
        if v == nil then return "?" end
        if issecretvalue and issecretvalue(v) then return "?" end
        if type(v) == "number" then return ("%.4g"):format(v) end
        return tostring(v)
    end
    local function Try(fn, ...) if type(fn) ~= "function" then return nil end; local ok, a, b = pcall(fn, ...); if ok then return a, b end end
    local function CV(name) local get = C_CVar and C_CVar.GetCVar or GetCVar; return S(Try(get, name)) end
    local out = {}
    local m = rawget(_G, "WorldMapFrame")
    if type(m) ~= "table" then
        out[#out + 1] = "world map: not loaded yet"
    else
        local w, h = Try(m.GetSize, m)
        local maxd = Try(m.IsMaximized, m)
        out[#out + 1] = ("world map: shown %s, maximized %s, size %s x %s, scale %s, effective scale %s"):format(S(Try(m.IsShown, m)),
            S(maxd), S(w), S(h), S(Try(m.GetScale, m)), S(Try(m.GetEffectiveScale, m)))
    end
    local rule = C_GameRules and Enum and Enum.GameRule and Enum.GameRule.MaximizeWorldMapDisabled
    out[#out + 1] = ("CVars: miniWorldMap %s (1 = opens small, 0 = opens full screen), questLogOpen %s, useUiScale %s, uiScale %s; game rule MaximizeWorldMapDisabled %s"):format(
        CV("miniWorldMap"), CV("questLogOpen"), CV("useUiScale"), CV("uiScale"), rule and S(Try(C_GameRules.IsGameRuleActive, rule)) or "?")
    local u = rawget(_G, "UIParent")
    if type(u) == "table" then
        local w, h = Try(u.GetSize, u)
        out[#out + 1] = ("UIParent: shown %s, size %s x %s, scale %s, effective scale %s"):format(S(Try(u.IsShown, u)), S(w), S(h),
            S(Try(u.GetScale, u)), S(Try(u.GetEffectiveScale, u)))
    end
    local slots = {}
    for _, k in ipairs({ "fullscreen", "left", "center", "right", "doublewide" }) do
        local f = Try(rawget(_G, "GetUIPanel"), k)
        local n = type(f) == "table" and Try(f.GetName, f) or nil
        slots[#slots + 1] = k .. " " .. (f and S(n or "(unnamed)") or "-")
    end
    out[#out + 1] = "Blizzard's panel slots: " .. table.concat(slots, ", ")
    if #mapOrder == 0 then
        out[#out + 1] = "XayaUI calls into Blizzard's panel layout since login: none"
    else
        local now = GetTime and GetTime() or 0
        for _, name in ipairs(mapOrder) do
            local t = mapTrace[name]
            out[#out + 1] = ("XayaUI since login: %s x%d (last %ds ago)"):format(name, t.n, math.floor(now - (t.last or now) + 0.5))
        end
    end
    return out
end
ns.MapReportLines = MapLines   -- (tests)
function ns.MapReport()
    for _, l in ipairs(MapLines()) do ns.Print("map: " .. l) end
end
