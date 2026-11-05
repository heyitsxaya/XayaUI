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
-- 4. Minimap button list. entry = { key, label, tooltip, action, stateFn (optional), order = number }
-- Positional fields keep MinimapButton.lua's row code unchanged. Lower order is higher in the list.
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
