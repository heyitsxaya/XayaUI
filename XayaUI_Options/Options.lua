-------------------------------------------------------------------------------
-- Options.lua : tabbed settings window built on AceConfig-3.0 / AceGUI-3.0,
-- plus an attached debug-console tray (status + event log) under the window.
--
-- Since the platform split P3 (Options 0.6.83; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7) this file is the window's plumbing:
-- the top tabs, the shared helpers (ns.OptionsApi), the feature tabs built from the pages each module registers, and the Platform
-- pages (Settings, Profiles with the Recycle Bin, the minimap button, Debugging). The rule editor and the rules tree (the Rules tab)
-- live in the rule editor (P3: XayaUI_Options/RuleEditor/); they reach this file only through ns.OptionsApi.Shared, and it reaches them through ns.OptionsApi.RuleEditor.
-- Since Options 0.6.107 (A23 SD-6) that code is part of XayaUI Rules (XayaUI_Rules/Editor/), set up by ns.OptionsApi.LoadRuleEditor (below)
-- loads it when the window opens while XayaUI Rules is on; the row painting every tab shares is TreePaint.lua.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local CoreS, PlatS, QolS = ns.Settings("core"), ns.Settings("platform"), ns.Settings("qol")   -- (Options 0.6.82, P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)

local APP = "CueRules"
local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)
local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
if not (AceConfigRegistry and AceConfigDialog) then
    local function missing() ns.Print("the settings window cannot open: its Ace3 libraries are missing (check the Libs folder of XayaUI_Options).") end
    ns.Options = { Toggle = missing, EditRule = missing, EditFolder = missing, OpenPage = missing, IsOpen = function() return false end }
    return
end
-- what XayaUI core may call (Modules.lua section 7); published as ns.Options at the end of this file once everything loaded.
-- A table field, not locals: this chunk is near Lua's 200-locals limit.
ns.OptionsApi = {}
-- (P3) what this window asks of the rule editor (XayaUI_Rules/Editor/ since Options 0.6.107; filled when it is set up, empty while XayaUI Rules is off):
-- BuildRulesTab, SettingsRows, SelectedRule, StatusText, and the editor's hooks the window calls (published at the end of
-- XayaUI_Rules/Editor/RuleSettings.lua); every call checks the entry is there
ns.OptionsApi.RuleEditor = {}
local RE = ns.OptionsApi.RuleEditor
-- The feature tabs: module -> top tab key, name and position. Pages inside a tab sort alphabetically by their shown name (Xaya,
-- 2026-11-02, #274); the older QoL Elements entries (shelved; qolExtra) come last.
-- Blizzard UI Reskin (Options 0.6.38; Xaya 2026-11-05: "Take all reskins and put them into a new tab: Blizzard UI Reskin. Currently
-- applies to: chat, character pane, Esc menu. Will apply in the future to: shopping list"): every page registered under module
-- "reskin": the Chat Panel (XayaUI_Chat), the Character Pane (XayaUI_QoL) and the Esc Menu (XayaUI_Reskin). The Chat tab is gone with
-- it (the Chat Panel was its only page); a tab with no pages is not drawn.
-- a group and everything in it to the Recycle Bin, by id (the Dev Assist QA walkthroughs clean up their test group with it)
function ns.OptionsApi.DeleteFolderAll(id) if RE.DeleteFolderAllById then return RE.DeleteFolderAllById(id) end end
ns.OptionsApi.TABS = { chat = { key = "chat", name = "Chat", order = 5 }, qol = { key = "qol", name = "QoL", order = 5.1 },
    bonus = { key = "bonus", name = "Bonus Features", order = 5.2 }, reskin = { key = "reskin", name = "Blizzard Reskin", order = 5.3 } }
-- (Options 0.6.72; REQUEST-LOG UI-23 to UI-27, Xaya 2026-11-06: tab label "Blizzard Reskin"; the toolbar goes and the top row reads
-- Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings.) Every top tab key, for the top-row layout (Skin.lua IsTopRow).
ns.OptionsApi.TOP_KEYS = { cooldowns = true, chat = true, qol = true, bonus = true, reskin = true, profiles = true, set = true, settings = true }
ns.OptionsApi.pageTab = {}   -- page key -> the top tab it is drawn in (filled by ModuleTabs), so a page that moved still opens
ns.OptionsApi.featureParents = {}   -- module -> { [page key] = true } for pages whose parts are left-pane nodes (filled by ModuleTabs)
-- Feature tabs: a feature's node starts open, so its parts show in the left pane right away (Xaya, 2026-11-03). Only the first
-- time per session: a node the user closed with its arrow stays closed.
function ns.FeatureTreesOpen()
    if not AceConfigDialog.GetStatusTable then return end
    for module, tab in pairs(ns.OptionsApi.TABS) do
        local parents = ns.OptionsApi.featureParents[module]
        if parents and next(parents) then
            local st = AceConfigDialog:GetStatusTable(APP, { tab.key })
            if st then
                st.groups = st.groups or {}
                st.groups.groups = st.groups.groups or {}
                for key in pairs(parents) do if st.groups.groups[key] == nil then st.groups.groups[key] = true end end
            end
        end
    end
end
-- Picking a feature's own node opens it too (a closed node shows its parts again). Called by the sidebar's Select (Skin.lua).
function ns.OptionsApi.OpenOnSelect(tree, uv)
    if type(uv) ~= "string" or not AceConfigDialog.GetStatusTable then return end
    local status = tree and (tree.status or tree.localstatus)
    if not status then return end
    for module, tab in pairs(ns.OptionsApi.TABS) do
        local parents = ns.OptionsApi.featureParents[module]
        if parents and parents[uv] then
            local st = AceConfigDialog:GetStatusTable(APP, { tab.key })
            if st and st.groups == status then status.groups = status.groups or {}; status.groups[uv] = true; return end
        end
    end
end
function ns.SettingsTabOf(module) local t = ns.OptionsApi.TABS[module]; return t and t.key or "qol" end
-- The Blizzard UI Reskin tab's own switch (Options 0.6.50, S1 #48; Xaya 2026-11-05: "double: both enable/disable of reskin at all; then
-- individual toggles for individual reskins"; 2026-11-06, where it goes: "Tick box on the tab itself"). A tick box on the tab button
-- in the window's top tab row. Unticked, every reskin in the tab is off at once (core ns.SetReskinTab); each reskin keeps its own box on
-- its row in the left pane, greyed while this is off.
-- Painted by ns.OptionsApi.PaintTabSwitches on every decorate pass (each redraw, and the window's 0.25 s tick), so a re-layout of the
-- tab row by AceGUI (a resize, a tab switch) is followed within a quarter second. The tab is made wider by the box, and its text moves
-- right by the same amount, so the box never covers the name. Other tabs have no box (a recycled tab button hides its own).
-- (Options 0.6.55; REQUEST-LOG UI-5 / UI-7; Xaya 2026-11-06: "Blizzard UI Reskin is not a check box at the top level. the check box
-- should be enable and disable in the tab itself and then after a reload individual reskin items populate", her answer "Right pane +
-- reload prompt".) The tab button carries no box any more (this table is empty; PaintTabSwitch hides a box a recycled button had).
-- The switch is the first row of the tab, Overview (ns.OptionsApi.ReskinOverview below): ticking or unticking it saves the choice for every
-- reskin and asks "Reload now?" (since Options 0.6.90 nothing changes before the reload; PS-57); the reskins' own rows are listed only when the switch was on when
-- this settings addon loaded (it loads on the first open after a login or /reload), so they appear after a reload.
ns.OptionsApi.TAB_SWITCHES = {}
ns.OptionsApi.reskinAtLoad = ns.ReskinTabOn and ns.ReskinTabOn() or false   -- the switch as it was when this addon loaded
ns.OptionsApi.RESKIN_SWITCH = "Enable Blizzard Reskin"
function ns.OptionsApi.ReskinOverview(args)
    for key, page in pairs(args) do
        if type(page) == "table" then
            local old = page.hidden
            page.hidden = function(...)
                if not ns.OptionsApi.reskinAtLoad then return true end
                if type(old) == "function" then return old(...) end
                return old
            end
        end
    end
    args.reskinOverview = { type = "group", name = "Overview", order = 0, args = {
        enable = { type = "toggle", order = 1, width = "full", name = ns.OptionsApi.RESKIN_SWITCH,
            desc = "Turns every reskin in this tab on or off together, after a reload; each keeps its own tick box. The reskins are listed in this tab after the reload.",
            -- (Options 0.6.90; PS-57, #480) saves the choice and asks for a reload; the reskins keep what they had until then
            -- (Modules.lua section 5c). Before: every reskin switched at once (ns.SetReskinTab) and then the prompt.
            get = function() return ns.ReskinTabSaved() end,
            set = function(_, v) ns.SaveReskinTab(v and true or false) end },
        note = { type = "description", order = 2, width = "full", fontSize = "medium",
            name = function()
                local now = ns.ReskinTabSaved()
                if now ~= ns.OptionsApi.reskinAtLoad then return "Changed: /reload to apply it and list the reskins as they are now." end
                return now and "The reskins are in the rows under Overview." or "Tick it, then /reload: the reskins are listed under Overview."
            end },
    } }
end
-- "Reload now?" (Reload / Later). C_UI.Reload (no arguments, no returns; ReloadUI if it is missing, as Console.lua does);
-- StaticPopupDialogs / StaticPopup_Show: Blizzard's FrameXML globals, checked before use.
-- (Options 0.6.90; PS-57, #480) every reskin and module switch asks with it (Modules.lua ns.SwitchSaveForReload); label names the part.
-- StaticPopup_Show(which, text_arg1) puts text_arg1 in the dialog's "%s" (Blizzard's StaticPopup.lua formats the text with it;
-- FrameXML, not in docs/reference/api: INFERENCE from Blizzard's own dialogs, e.g. "%s has invited you to a group.").
ns.OptionsApi.RELOAD_TEXT = "%s: this change takes effect after a reload. Reload now?"
function ns.OptionsApi.ReloadPrompt(label)
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return end
    if not StaticPopupDialogs.XAYAUI_RESKIN_RELOAD then
        StaticPopupDialogs.XAYAUI_RESKIN_RELOAD = { text = ns.OptionsApi.RELOAD_TEXT,
            button1 = "Reload", button2 = "Later", OnAccept = function() local r = (C_UI and C_UI.Reload) or ReloadUI; if type(r) == "function" then r() end end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
    end
    StaticPopup_Show("XAYAUI_RESKIN_RELOAD", (type(label) == "string" and label ~= "") and label or "XayaUI")
end
ns.OptionsApi.TAB_BOX = 14   -- the tick box's size on the tab
function ns.OptionsApi.PaintTabSwitches(root)
    local function walk(w, d)
        if not w or d > 3 then return end
        if w.type == "TabGroup" and w.tabs then
            for _, tab in ipairs(w.tabs) do ns.OptionsApi.PaintTabSwitch(tab) end
        end
        for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
    end
    walk(root, 0)
end
function ns.OptionsApi.PaintTabSwitch(tab)
    local sw = tab:IsShown() and ns.OptionsApi.TAB_SWITCHES[tab.value or ""]
    local box = tab.xuiTabBox
    local fs = tab.GetFontString and tab:GetFontString()
    if not sw then
        if box then box:Hide() end
        if tab.xuiTabShift then   -- this button showed a box for another tab group before: its text goes back to AceGUI's place
            tab.selectedTextX, tab.deselectedTextX, tab.xuiTabShift = nil, nil, nil
        end
        return
    end
    local W = ns.OptionsApi.TAB_BOX
    if not box then
        box = CreateFrame("CheckButton", nil, tab, "UICheckButtonTemplate")
        box:SetSize(W, W)
        box:EnableMouse(true)   -- the box takes the click, not the tab under it
        box:SetScript("OnClick", function(self)
            local s = ns.OptionsApi.TAB_SWITCHES[(self:GetParent() or {}).value or ""]
            if not s then return end
            local ok, err = pcall(s.set, self:GetChecked() and true or false)
            if not ok then local h = geterrorhandler and geterrorhandler(); if h then h(err) end end
            if ns.Fire then ns.Fire("CONFIG_CHANGED") end   -- a redraw (the window's Notify): the reskins' row boxes repaint, greyed or not
        end)
        box:SetScript("OnEnter", function(self)
            local s = ns.OptionsApi.TAB_SWITCHES[(self:GetParent() or {}).value or ""]
            if not s then return end
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
            GameTooltip:SetText(s.name)
            GameTooltip:AddLine(s.desc, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tab.xuiTabBox = box
    end
    box:SetFrameLevel(tab:GetFrameLevel() + 3)
    local ok, on = pcall(sw.get)
    box:SetChecked((ok and on) and true or false)
    -- room for the box: the tab grows by it (AceGUI sized it to its text) and the text moves right by half of it (it is centred)
    local shift = W + 2
    local tw = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
    local need = tw + 26 + shift
    local cur = tab:GetWidth() or 0
    if cur < need then
        local grow = need - cur
        tab:SetWidth(need)
        for _, k in ipairs({ "Middle", "MiddleDisabled" }) do local t = tab[k]; if t and t.GetWidth then t:SetWidth((t:GetWidth() or 0) + grow) end end
    end
    tab.selectedTextX, tab.deselectedTextX, tab.xuiTabShift = shift / 2, shift / 2, true
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", tab, "CENTER", shift / 2, tab.selected and (tab.selectedTextY or -3) or (tab.deselectedTextY or 2))
    end
    box:ClearAllPoints()
    box:SetPoint("LEFT", tab, "LEFT", 11, tab.selected and -3 or 1)
    box:Show()
end

function ns.OptionsApi.ModuleTabs(Notify, qolExtra)
    local out = {}
    for module, tab in pairs(ns.OptionsApi.TABS) do
        local args = ns.BuildSettingsPages(module, Notify)
        if module == "qol" and qolExtra then for k, v in pairs(qolExtra) do args[k] = v end end
        if module == "reskin" and next(args) then pcall(ns.OptionsApi.ReskinOverview, args) end
        -- (Options 0.6.104, #472) each restyled element's page gets its one "Theme" row (ScopeEditor.lua; Xaya's Q9 answer "Both")
        if module == "reskin" and ns.OptionsApi.ScopeEditor then pcall(ns.OptionsApi.ScopeEditor.AddRows, args) end
        local list = {}
        for key, ent in pairs(args) do
            local nm = ent.name
            if type(nm) == "function" then local ok, v = pcall(nm); nm = ok and v or nil end
            nm = (type(nm) == "string" and nm ~= "") and nm:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or key
            local old = (key == "allqol" or key == "allcursor" or key == "allbars") and 1 or (key == "reskinOverview" and -1) or 0
            list[#list + 1] = { key = key, name = nm:lower(), old = old }
        end
        table.sort(list, function(a, b)
            if a.old ~= b.old then return a.old < b.old end
            if a.name ~= b.name then return a.name < b.name end
            return a.key < b.key
        end)
        for i, e in ipairs(list) do args[e.key].order = i; ns.OptionsApi.pageTab[e.key] = tab.key end
        -- a feature node with parts under it (childGroups = "tree", Modules.lua ns.SectionTabs note) starts open: ns.FeatureTreesOpen
        local parents = {}
        for key, ent in pairs(args) do
            if ent.childGroups == "tree" then
                for _, sub in pairs(ent.args or {}) do
                    if type(sub) == "table" and sub.type == "group" and not sub.inline then parents[key] = true; break end
                end
            end
        end
        ns.OptionsApi.featureParents[module] = parents
        for _, ent in pairs(args) do if type(ent) == "table" and ent.type == "group" then pcall(ns.OptionsApi.GreyWhileOff, ent, {}) end end
        if next(args) then out[tab.key] = { type = "group", name = tab.name, order = tab.order, childGroups = "tree", args = args } end
    end
    return out
end

-- (Options 0.6.55; REQUEST-LOG UI-5 / UI-8; Xaya 2026-11-06: "all options that are deselected should grey out to indicate they are
-- disabled", her answer "Left pane + their settings".) While a feature's switch (group.xuiSwitch) is off, every setting on its pages
-- and on its parts' pages is greyed (AceConfig "disabled"; the controls cannot be changed), and a part's own switch is greyed too.
-- The pages stay open to look at: a non-inline group is never disabled itself (AceConfigDialog would grey and lock its left-pane
-- row). A "disabled" given as a handler method name (a string) is left as it is (it cannot be wrapped here).
function ns.OptionsApi.GreyWhileOff(g, offs)
    local sw = g.xuiSwitch
    local mine = offs
    if type(sw) == "table" and type(sw.get) == "function" then
        if #offs > 0 then ns.OptionsApi.WrapDisabled(sw, offs) end
        mine = {}
        for i, f in ipairs(offs) do mine[i] = f end
        mine[#mine + 1] = function(info) local ok, v = pcall(sw.get, info); return ok and not v end
    end
    -- (Options 0.6.63; UI-46: "clicking on a deactivated item should just show the summary without a nested box"; UI-48: "If the
    -- item is not enabled no additional fill should exist") while off, a page's section tabs (childGroups "tab") are not drawn: no tab
    -- row and no box under it, only the page's own text. Parts listed in the left pane (childGroups "tree") stay, greyed.
    if #mine > 0 and g.childGroups == "tab" then
        -- a page whose text is all inside its section tabs (Data Panels, Enhanced Tooltips) would be empty while off: it shows its
        -- switch's one sentence (Options 0.6.63, UI-46 "just show the summary"; which text is the summary is a session choice)
        local own = false
        for k, o in pairs(type(g.args) == "table" and g.args or {}) do
            -- (Options 0.6.90) an overlap flag (Modules.lua 5d, xuiConflict) is not the page's own text: the summary still shows
            if k ~= "xuiConflict" and type(o) == "table" and (o.type ~= "group" or o.inline) then own = true; break end
        end
        if not own and type(sw) == "table" and type(g.args) == "table" and not g.args.xuiOffSummary then
            local offs2 = mine
            g.args.xuiOffSummary = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = function(info) local f = ns.OptionsApi.SwitchSentence; return f and f(sw, info) or "" end,
                hidden = function(info) for _, off in ipairs(offs2) do if off(info) then return false end end return true end }
        end
        for _, o in pairs(type(g.args) == "table" and g.args or {}) do
            if type(o) == "table" and o.type == "group" and not o.inline and not o.xuiOffHidden then
                o.xuiOffHidden = true
                local oldH = o.hidden
                if type(oldH) ~= "string" then
                    o.hidden = function(info, ...)
                        for _, off in ipairs(mine) do if off(info) then return true end end
                        if type(oldH) == "function" then return oldH(info, ...) end
                        return oldH
                    end
                end
            end
        end
    end
    for k, o in pairs(type(g.args) == "table" and g.args or {}) do
        if type(o) == "table" and k ~= "xuiConflict" then   -- (Options 0.6.90) the overlap flag is never greyed
            if o.type == "group" and not o.inline then ns.OptionsApi.GreyWhileOff(o, mine)
            elseif #mine > 0 then
                ns.OptionsApi.WrapDisabled(o, mine)
                if o.type == "group" then ns.OptionsApi.GreyWhileOff(o, mine) end
            end
        end
    end
end
function ns.OptionsApi.WrapDisabled(o, offs)
    local old = o.disabled
    if type(old) == "string" or o.xuiGreyWrapped then return end
    o.xuiGreyWrapped = true
    o.disabled = function(info, ...)
        for _, off in ipairs(offs) do if off(info) then return true end end
        if type(old) == "function" then return old(info, ...) end
        return old
    end
end
-- the row of a feature tab's left pane (the tab's own tree), its tree and its user data; nil for every other tree
function ns.OptionsApi.FeatureRow(button)
    local tree = button and button.obj
    local user = tree and tree.GetUserDataTable and tree:GetUserDataTable()
    local path = user and user.path
    if type(path) ~= "table" or #path ~= 1 or not ns.OptionsApi.TABS[path[1] or ""] then return nil end
    return tree, user
end
-- (UI-5 / UI-8: "all options under a given section should be appropriately nested", her answer "Parent's name + 8 px") a part's row
-- starts 8 px right of where its parent's name starts (each name's left inset is noted as it is drawn; parents are drawn first)
function ns.OptionsApi.NestX(button, level, x0)
    if level < 2 then return x0 end
    local tree = ns.OptionsApi.FeatureRow(button)
    local parent = tree and tostring(button.uniquevalue or ""):match("^(.+)\001[^\001]+$")
    local pl = parent and tree.xuiNameL and tree.xuiNameL[parent]
    return pl and (pl + ns.Style.nest.child) or x0
end
function ns.OptionsApi.NoteNameL(button)
    local tree = ns.OptionsApi.FeatureRow(button)
    if not (tree and button.xuiTextL) then return end
    tree.xuiNameL = tree.xuiNameL or {}
    tree.xuiNameL[tostring(button.uniquevalue or "")] = button.xuiTextL
end
-- an unticked feature's row (or a part of one) shows its name in grey
ns.OptionsApi.GREY = ns.Style.grey   -- (core ns.Style, UI-47)
-- (Options 0.6.63; UI-49 "theme has to tie into the skin.lua in some way") the grey is the theme's Muted text colour ("Hints and
-- disabled items"); ns.Style.grey only when the theme is missing
function ns.OptionsApi.Muted()
    local TH = ns.Theme
    return (TH and TH.Col) and TH.Col("xui-text-muted", "text", "settings", ns.OptionsApi.GREY) or ns.OptionsApi.GREY   -- (#472: the settings window's scope)
end
function ns.OptionsApi.RowOff(button)
    local tree, user = ns.OptionsApi.FeatureRow(button)
    if not tree then return false end
    local g = user.option
    local info = { user.path[1] }
    local segs = {}
    for seg in tostring(button.uniquevalue or ""):gmatch("[^\001]+") do segs[#segs + 1] = seg end
    for _, seg in ipairs(segs) do
        g = type(g) == "table" and type(g.args) == "table" and g.args[seg] or nil
        if type(g) ~= "table" then return false end
        info[#info + 1] = seg
        local sw = g.xuiSwitch
        if type(sw) == "table" and type(sw.get) == "function" then
            local ok, v = pcall(sw.get, info)
            if ok and not v then return true end
        end
    end
    return false
end
function ns.OptionsApi.GreyRow(button)
    local fs = button and button.text
    if not (fs and ns.OptionsApi.RowOff(button)) then return end
    local t = fs:GetText()
    if type(t) == "string" and t:find("|c", 1, true) then fs:SetText((t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))) end
    local c = ns.OptionsApi.Muted()
    fs:SetTextColor(c[1], c[2], c[3])
end

-- The options tree drawn last, kept for a redraw that changes nothing in it (Options 0.6.39; Xaya 2026-11-05: "console toggle has a
-- still long time"). Every redraw of the window builds the whole tree (every rule, in several lists): 0.44-0.64 s of Lua with 229 rules
-- in the test harness, and a click on a switch redraws at least once (AceConfigDialog redraws after every toggle). A switch whose
-- change shows only in its own tick (the console window, the debug console strip) calls Tree.Keep() so the redraw that follows in
-- the same call reuses the tree. Single use; only while the window is open; the window driver drops it every frame, and any
-- Notify() cancels it, so a change that needs a fresh tree always gets one.
-- Tree.ViewChanged(): the same kind of change made outside the window (the console's close X, /xui console): one redraw on the next
-- frame that reuses the tree, skipped when AceConfigDialog already has a redraw of its own pending (that one builds fresh).
local Tree = {}
function Tree.Keep()
    local open = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    Tree.keep = (open and Tree.last) and true or nil
end
function Tree.Get(...)
    if Tree.keep and Tree.last then Tree.keep = nil; return Tree.last end
    Tree.keep = nil
    Tree.lazy = true   -- (Options 0.6.69) the window's build: rule editors only for what it draws (BuildOptions, ns.OptionsApi.FillRule)
    local ok, t = pcall(ns.BuildOptionsTable, ...)
    Tree.lazy = nil
    if not ok then error(t, 0) end
    Tree.last = t
    return Tree.last
end
-- AceConfigDialog keeps the apps waiting for its next-frame redraw in AceConfigDialog.frame.apps (AceConfigDialog-3.0.lua
-- ConfigTableChanged / RefreshOnUpdate, the copy in Libs/)
function Tree.AcePending() local f = AceConfigDialog.frame; return (f and f.apps and f.apps[APP]) and true or false end   -- (a field: this file is at Lua's 200-local limit)
-- a redraw asked for before a full Open that has just happened is not needed (the Open drew the latest tree): drop it (Options 0.6.68)
function Tree.DropPending() local f = AceConfigDialog.frame; if f and f.apps then f.apps[APP] = nil end end
function Tree.ViewChanged()
    local token = {}
    Tree.view = token
    C_Timer.After(0, function()
        if Tree.view ~= token then return end   -- cancelled by Notify(), or a later request replaced it
        Tree.view = nil
        local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
        if not (of and of.frame and of.frame:IsShown()) or Tree.AcePending() then return end
        local user = of:GetUserDataTable()
        Tree.Keep()
        pcall(AceConfigDialog.Open, AceConfigDialog, APP, unpack(user.basepath or {}))
        Tree.keep = nil
    end)
end
-- Tree.hold: a sidebar tick box is running its switch's set (Tree.SwitchClick); a redraw that set asks for is dropped and the click
-- makes the one redraw itself.
local function Notify() if Tree.hold then return end Tree.keep, Tree.view = nil, nil; if RE.SaveRulesSub then pcall(RE.SaveRulesSub) end if RE.SmartOpen then pcall(RE.SmartOpen) end if ns.FeatureTreesOpen then pcall(ns.FeatureTreesOpen) end if RE.FixSelection then pcall(RE.FixSelection) end AceConfigRegistry:NotifyChange(APP) end


-------------------------------------------------------------------------------
-- Small option builders
-------------------------------------------------------------------------------
local function Col(t, k, name, order, on, extra)
    local o = { type = "color", name = name, order = order, hasAlpha = true,
        get = function() local c = t[k] or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
        set = function(_, r, g, b, a) t[k] = { r, g, b, a }; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
local function Rng(t, k, name, order, min, max, step, on, extra)
    local o; o = { type = "range", name = name, order = order, min = min, max = max, step = step,
        get = function() if t[k] ~= nil then return t[k] end if o.def ~= nil then return o.def end return min end, set = function(_, v) t[k] = v; on() end }   -- def: what the engine uses when the value was never set
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
local function Tog(t, k, name, order, on, extra)
    local o = { type = "toggle", name = name, order = order,
        get = function() return t[k] and true or false end, set = function(_, v) t[k] = v; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
local function Sel(t, k, name, order, vals, ord, on, extra)
    local o = { type = "select", name = name, order = order, values = vals, sorting = ord,
        get = function() return t[k] end, set = function(_, v) t[k] = v; on() end }
    if extra then for kk, vv in pairs(extra) do o[kk] = vv end end
    return o
end
-- Shared option builders for other files (Triggers.lua builds its rows with these). A table, so no new top-level local.
-- a rebuild that grows or shrinks the page needs a second pass a moment later, or the scroll area keeps its old height (content clips, no scrollbar)
ns.UI = { NotifyTwice = function() Notify() end, Sel = Sel, Rng = Rng, Tog = Tog, Notify = Notify }   -- (P3) the rule editor (XayaUI_Rules/Editor/Editor.lua) adds Changed, SpellName, SpellTex, SearchBox
-- (Options 0.6.83, P3 options split; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7) The rule editor and the rules tree live in
-- XayaUI_Rules/Editor/ (set up after this addon loaded). What they use of this window, their only way in:
ns.OptionsApi.Shared = { APP = APP, AceConfigRegistry = AceConfigRegistry, AceConfigDialog = AceConfigDialog, Tree = Tree, Notify = Notify,
    CoreS = CoreS, PlatS = PlatS, QolS = QolS, Col = Col, Rng = Rng, Tog = Tog, Sel = Sel }
-- ...and what this file asks of them: ns.OptionsApi.RuleEditor (RE, made at the top of this file)
-------------------------------------------------------------------------------
-- Import / Export tab: export rules as text, import rules from text, and backups of your rules saved on this computer (Share.lua).
-- Themes have their own import and export (Settings > UI Options > Theme).
-------------------------------------------------------------------------------
local exportInc = { rules = true, bars = true, qol = true }
local exportText = ""
local importText, importSnap, importErr = "", nil, nil
local backupName, shareMsg = "", ""
-- (Options 0.6.72; UI-26 / UI-27) Profiles > Export: one tick box per component (Profiles.lua); Profiles > Import: the components the
-- pasted text holds, each ticked to start; rules are added as a new group or replace yours
local profInc = { rules = true, themes = true, settings = true, qol = true, bonus = true, reskin = true }
local importDef, importInc, importRulesMode = nil, {}, "add"

local function ParseImport()
    importSnap, importErr, importDef = nil, nil, nil
    importInc = {}
    if (importText or ""):match("%S") then
        local data, defOrErr = ns.Share.Read(importText)
        if data then
            importSnap, importDef = data, defOrErr
            if importDef.kind == "profile" and ns.Profile then for _, c in ipairs(ns.Profile.Held(data)) do importInc[c.key] = true end end
        else
            importErr = defOrErr
        end
    end
end
ns.OptionsApi.ProfileState = function() return { profInc = profInc, importInc = importInc, importDef = importDef, importSnap = importSnap, importErr = importErr } end
-- (Options 0.6.80) for XayaUI Dev Assist's platform walkthrough (QAWalks-platform.lua): paste a text into Profiles > Import as the box
-- would, and read the Profiles tab as the window builds it
ns.OptionsApi.SetImportText = function(t) importText = tostring(t or ""); ParseImport(); if ns.Fire then ns.Fire("CONFIG_CHANGED") end end
-- the whole settings table, built in full (not the window's lazy build), for Dev Assist's QA checks (QAWalks-layout-fixes.lua B313)
ns.OptionsApi.BuiltTable = function() return ns.BuildOptionsTable and ns.BuildOptionsTable() end
ns.OptionsApi.ProfilesTable = function() local b = ns.BuildOptionsTable and ns.BuildOptionsTable(); return b and b.args and b.args.profiles end

local function AddonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(get, ns.name or "XayaUI", "Version")   -- XayaUI core's version (this file is in XayaUI_Options)
    return (ok and v) or "?"
end

-- Page switching (2026-10-31 UI pass): Class/Spec Rule Creator, Profiles (Export / Import) and Settings are not in the tab strip
-- while the skin is on. The toolbar buttons open them (ns.pageOpen) and the tab goes away again as soon as another tab is picked.
-- With the skin off (/xuiskin) they stay ordinary tabs, because the toolbar does not exist then.
-- (Options 0.6.72; UI-23 to UI-27) Settings and Profiles are ordinary top tabs and the Recycle Bin is a sub-tab of Profiles, so no
-- page is hidden any more; kept so an older caller still gets a valid "hidden" function.
function ns.PageHidden(key)
    return function() return false end
end

-- Settings > Display Options / Debugging readers (used by the tree painting and the debug console tray)
function ns.SelStyle() local u = PlatS.ui; return (u and u.selStyle == "bar") and "bar" or "text" end
function ns.ParentGradientOn() local u = PlatS.ui; return not (u and u.parentGradient == false) end
function ns.SidebarSpellIcons() local u = PlatS.ui; return not (u and u.sidebarSpellIcons == false) end
function ns.GridOn() return true end   -- two-column grid is always on (no longer an option)
function ns.CondensedOn() local u = PlatS.ui; return u and u.condensedList == true or false end

-- Window size override (Settings > UI Options > Window Size, issue #223). 0 = automatic (the built-in 780 x 860). A saved value is clamped to
-- the screen and to a usable minimum. It is applied on the first open each session (see the Open hook) and immediately when changed.
ns.PANE_DEFAULT_W, ns.PANE_DEFAULT_H = 780, 860
ns.PANE_MIN_W, ns.PANE_MIN_H = 600, 400
function ns.PaneSize()
    local u = PlatS.ui
    local w, h = tonumber(u and u.paneW) or 0, tonumber(u and u.paneH) or 0
    local sw = UIParent and UIParent:GetWidth() or 1920
    local sh = UIParent and UIParent:GetHeight() or 1080
    if w <= 0 then w = ns.PANE_DEFAULT_W else w = math.max(ns.PANE_MIN_W, w) end
    if h <= 0 then h = ns.PANE_DEFAULT_H else h = math.max(ns.PANE_MIN_H, h) end
    return math.min(w, sw), math.min(h, sh)
end
function ns.ApplyPaneSize()
    local w, h = ns.PaneSize()
    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    if not ACD then return end
    pcall(ACD.SetDefaultSize, ACD, APP, w, h)   -- the size the next open uses
    local of = ACD.OpenFrames and ACD.OpenFrames[APP]
    if of and of.frame then pcall(of.frame.SetSize, of.frame, w, h) end   -- and the open window, right now
end
function ns.DebugConsoleOn() local u = PlatS.ui; return not (u and u.hideTray) end

-- Settings: the addon's own behavior, as opposed to any one rule's. Opened from the toolbar (cog, far right); has its own tabs.
-- (Options 0.6.84, P4) XayaUI Rules is loaded: its "rules" service is there (XayaUI_Rules/RuleDefaults.lua). Off: the Rules tab, the rule
-- list rows and the Rule Creation tab of Settings, and the rule backups under Profiles > Export are left out (nothing of the rule editor
-- is built); the rest of the window is the same.
local function RulesOn() return (ns.Service and ns.Service("rules")) and true or false end
-- (Options 0.6.107, REQUEST-LOG A23 SD-6) The rule editor is part of XayaUI Rules (XayaUI_Rules/Editor/; it was the load-on-demand
-- addon XayaUI_Rules_Options). The game reads its files with Rules at login; each file only adds one set-up function to
-- ns.RuleEditorFiles, in .toc order. They run here, once per session, after this addon has finished loading: from core's
-- ns.LoadOptions (Modules.lua, through ns.Options.AfterLoad) and, for a caller that loaded this addon some other way, from Toggle; only
-- while XayaUI Rules is on. So no editor frame, popup, listener or hook exists before the window opens. A file whose set-up errors is
-- reported through the game's error handler and the others still run, as when the game loads a .toc. The list is then dropped, so the
-- set-up code itself can be freed (the functions it made stay).
-- EditorOn: the Rules tab and the rule rows of Settings are built only when the editor is there (XayaUI Rules on, editor set up).
local function EditorOn() return RulesOn() and ns.OptionsApi.RuleEditor.BuildRulesTab ~= nil end
function ns.OptionsApi.LoadRuleEditor()
    if ns.OptionsApi.ruleEditorTried or not RulesOn() then return EditorOn() end
    ns.OptionsApi.ruleEditorTried = true
    local files = ns.RuleEditorFiles
    ns.RuleEditorFiles = nil
    if type(files) == "table" then
        local handler = (geterrorhandler and geterrorhandler()) or function(e) ns.Print(tostring(e)) end
        for i = 1, #files do xpcall(files[i], handler) end
    end
    if not EditorOn() then
        ns.Print("the rule editor could not be set up: the Rules tab is left out. /xui bug shows errors.")
    end
    return EditorOn()
end
ns.OptionsApi.AfterLoad = ns.OptionsApi.LoadRuleEditor   -- called by core right after this addon loaded (Modules.lua ns.LoadOptions)
local function BuildAddonSettings()
    local function Ui() PlatS.ui = PlatS.ui or {}; return PlatS.ui end
    local function Repaint() if ns.DecorateTrees then pcall(ns.DecorateTrees) end; Notify() end
    local dispRows, ruleRows = {}, nil
    if EditorOn() then dispRows, ruleRows = ns.OptionsApi.RuleEditor.SettingsRows(Ui, Repaint) end   -- (P3) the rule list and Rule Creation rows (XayaUI_Rules/Editor/RuleSettings.lua)
    local page = { type = "group", name = "Settings", order = 7, childGroups = "tab", hidden = ns.PageHidden("settings"), args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = function() return "XayaUI v" .. AddonVersion() .. ". Settings here affect the whole addon, not any one rule." end },
        ui = { type = "group", name = "UI Options", order = 1, args = {
            paneHeader = { type = "header", name = "Window Size", order = 30 },
            paneNote = { type = "description", order = 30.5, width = "full",
                name = "Sets the size of this window when it opens. 0 = automatic (780 wide by 860 tall). Values are kept on screen and no smaller than 600 by 400. Dragging the window's corner still resizes it for the current session." },
            paneW = { type = "range", name = "Window width (0 = automatic)", order = 31, min = 0, max = 2560, step = 10, width = "double",
                get = function() return tonumber(Ui().paneW) or 0 end,
                set = function(_, v) Ui().paneW = v; if ns.ApplyPaneSize then ns.ApplyPaneSize() end end },
            paneH = { type = "range", name = "Window height (0 = automatic)", order = 32, min = 0, max = 1600, step = 10, width = "double",
                get = function() return tonumber(Ui().paneH) or 0 end,
                set = function(_, v) Ui().paneH = v; if ns.ApplyPaneSize then ns.ApplyPaneSize() end end },
            paneReset = { type = "execute", name = "Reset window size to automatic", order = 33, width = "double",
                func = function() Ui().paneW = 0; Ui().paneH = 0; if ns.ApplyPaneSize then ns.ApplyPaneSize() end; Notify() end },
            menuBtnHeader = { type = "header", name = "Menu button (ESC menu)", order = 23.5 },
            gameMenuButton = { type = "toggle", name = "Show a XayaUI button in the Game Menu (ESC menu)", order = 24, width = "full",
                desc = "Adds a XayaUI entry to the ESC menu that opens this window. Off: the entry is removed the next time the menu opens.",
                get = function() return not (PlatS.ui and PlatS.ui.hideGameMenuButton) end,
                set = function(_, v) Ui().hideGameMenuButton = (not v) or nil; if ns.GameMenu_OnOptionChanged then ns.GameMenu_OnOptionChanged() end end },
            gameMenuStyle = { type = "select", name = "Menu button style", order = 24.1, width = "double",
                desc = "Gradient button: class-colored fill, solid text. Standard button: the UI's flat button with class-colored text.",
                values = { gradient = "Gradient button, solid text", standard = "Standard button, gradient text" },
                sorting = { "gradient", "standard" },
                get = function() return (PlatS.ui and PlatS.ui.gameMenuStyle) or "gradient" end,
                set = function(_, v) Ui().gameMenuStyle = v; if ns.GameMenu_Repaint then ns.GameMenu_Repaint() end end },
        } },
        rules = ruleRows,   -- (P3) the Rule Creation tab: XayaUI_Rules/Editor/RuleSettings.lua
        theme = { type = "group", name = "Theme", order = 1.5, args = ns.Theme and ns.Theme.BuildArgs(Repaint) or {} },
        debug = { type = "group", name = "Debugging", order = 2, args = {
            debugHeader = { type = "header", name = "Debugging", order = 10 },
            advancedDebug = { type = "toggle", name = "Advanced Debugging (recommended)", order = 11, width = "full",
                desc = "Records XayaUI's own errors and warnings for the debug report (/xui report) and sends its messages to the console window. On by default; it does nothing while nothing goes wrong.",
                get = function() return PlatS.ui and PlatS.ui.advancedDebug and true or false end,
                set = function(_, v) Ui().advancedDebug = v and true or false; if ns.DebugSettingsChanged then ns.DebugSettingsChanged() end; Notify() end },
            -- the options Advanced Debugging brings (XayaUI/DebugRecord.lua)
            msgDest = { type = "select", name = "XayaUI's messages", order = 11.1,
                desc = "Sets where XayaUI's messages appear: chat, the console window, or both. Default: the console while Advanced Debugging is on, else chat.",
                values = { chat = "Chat window", console = "XayaUI console window", both = "Both" }, sorting = { "console", "chat", "both" },
                get = function() return ns.MessageDest and ns.MessageDest() or "chat" end,
                set = function(_, v) Ui().msgDest = v; Notify() end },
            consoleAutoOpen = { type = "toggle", name = "Open the console window when a message arrives", order = 11.2,
                desc = "Opens the console window when a message arrives (after combat, if in combat). Off: lines wait there until you open it (/xui console).",
                hidden = function() return not (ns.MessageDest and ns.MessageDest() == "console") end,
                get = function() return Ui().consoleAutoOpen ~= false end,
                set = function(_, v) if v then Ui().consoleAutoOpen = nil else Ui().consoleAutoOpen = false end end },
            -- (Options 0.6.55; REQUEST-LOG #82) the debug report: XayaUI's errors and warnings with their codes (core DebugRecord.lua). The
            -- detailed record (11 kinds of line, its switches, view and clear) is XayaUI Dev Assist's since core 0.6.56: its settings show
            -- under "Dev Assist (separate tool)" below while it is loaded.
            report = { type = "group", inline = true, name = "Debug report", order = 11.3, args = {
                repText = { type = "description", order = 1, width = "full", fontSize = "medium",
                    name = function()
                        local total, kinds, nErr, nWarn = 0, 0, 0, 0
                        if ns.ErrorCount then total, kinds, nErr, nWarn = ns.ErrorCount() end
                        return ("XayaUI records its own errors and warnings, each with a code, only when one happens (nothing is recorded or run while everything works). Now: %d error%s and %d warning%s (%d times in all). The debug report shows them for a screenshot, and as one string to copy and send to Xaya. Also: /xui report."):format(
                            nErr or 0, nErr == 1 and "" or "s", nWarn or 0, nWarn == 1 and "" or "s", total or 0)
                    end },
                repOpen = { type = "execute", name = "Open the debug report", order = 2, width = "double",
                    func = function() if ns.ShowDebugReport then ns.ShowDebugReport() end end },
            } },
            send = { type = "group", inline = true, name = "What to send", order = 11.9, args = {
                sendText = { type = "description", order = 1, width = "full", fontSize = "medium",
                    name = "1. Type /reload (or log out): the game writes the files only then.  2. Open the folder below (copy the path, then replace <YOUR ACCOUNT FOLDER> with your account's folder inside WTF\\Account, often a number such as 12345678#1; if there are several, use the one with the newest XayaUI.lua).  3. Send the files below to Xaya. They hold no password, character name, realm or chat text; XayaUI.lua holds your rule names and settings." },
                sendCore = { type = "input", name = "XayaUI.lua: your rules, settings, and saved errors and warnings  (click, Ctrl+A, Ctrl+C)", order = 2, width = "full",
                    get = function() return ns.SavedFilePath and ns.SavedFilePath("XayaUI.lua") or "" end,
                    set = function() end },
                sendDev = { type = "input", order = 3, width = "full",
                    name = function()
                        local svc = ns.Service and ns.Service("gameDataProbe")
                        return tostring(svc and svc.savedFile or "") .. ": " .. tostring(svc and svc.savedWhat or "the developer captures") .. "  (click, Ctrl+A, Ctrl+C)"
                    end,
                    hidden = function() local svc = ns.Service and ns.Service("gameDataProbe"); return not (svc and type(svc.savedFile) == "string") end,
                    get = function() local svc = ns.Service and ns.Service("gameDataProbe"); return (svc and ns.SavedFilePath) and ns.SavedFilePath(svc.savedFile) or "" end,
                    set = function() end },
                sendCopy = { type = "execute", name = "Copy all of this", order = 4,
                    desc = "Opens these steps and paths as one text, selected and ready for Ctrl+C.",
                    func = function() if ns.SendText and ns.ShowCopyBox then ns.ShowCopyBox("XayaUI: what to send", ns.SendText()) end end },
            } },
            showConsole = { type = "toggle", name = "Show the debug console at the bottom of the window", order = 12, width = "full",
                desc = "Shows the strip under the window with live rule status and the event log.",
                get = function() return ns.DebugConsoleOn() end,
                -- nothing in the tree changes: the strip is placed now (not on the driver's next tick) and the redraw AceConfigDialog
                -- makes after the click reuses the tree (Tree.Keep, Options 0.6.39)
                set = function(_, v) Ui().hideTray = (not v) or nil; Tree.Keep(); if ns.UpdateTrayNow then pcall(ns.UpdateTrayNow) end end },
            consoleWin = { type = "toggle", name = "Console window (separate from this window)", order = 13, width = "full",
                desc = "Opens the event log in its own movable window, which keeps collecting while this one is closed. Also: /xui console.",
                get = function() return ns.ConsoleWindowOn and ns.ConsoleWindowOn() or false end,
                -- (true: from this switch, so core asks for no redraw of its own; the one AceConfigDialog makes reuses the tree)
                set = function(_, v) if ns.ConsoleWindow then ns.ConsoleWindow(v and true or false, true) end; Tree.Keep() end },
            consoleCopy = { type = "execute", name = "Copy the console text", order = 13.5, width = "double",
                desc = "Opens a box with every console line as plain text, selected and ready for Ctrl+C.",
                func = function() if ns.CopyConsole then ns.CopyConsole() end end },
            bug = { type = "group", inline = true, name = "Bug report", order = 20, args = {
                bugInfo = { type = "description", order = 1, fontSize = "medium",
                    name = function()
                        local total, kinds = 0, 0
                        if ns.ErrorCount then total, kinds = ns.ErrorCount() end
                        return "XayaUI keeps its own Lua errors (" .. total .. " so far, " .. kinds .. " different) and saves them between sessions. The report holds the version, the game build, those errors, the last console lines and, with Advanced Debugging on, the debug record. It never includes your character name, realm, or your rules' settings; rule names appear in the console lines and the record. Send it to Xaya or paste it into a GitHub issue."
                    end },
                bugText = { type = "input", name = "What happened  (optional)", order = 2, width = "full", multiline = 4,
                    get = function() return Ui().bugText or "" end,
                    set = function(_, v) v = tostring(v or ""):sub(1, 600); Ui().bugText = (v ~= "") and v or nil end },
                bugAddons = { type = "toggle", name = "Also list my loaded addons", order = 3, width = "full",
                    desc = "Off by default: your addon list says a lot about you. Turn on if the problem may be a clash with another addon.",
                    get = function() return Ui().bugAddons and true or false end,
                    set = function(_, v) Ui().bugAddons = v and true or nil end },
                bugMake = { type = "execute", name = "Create bug report", order = 4, width = "double",
                    desc = "Opens a box with the report, selected and ready for Ctrl+C. Also: /xui bug.",
                    func = function() if ns.ShowBugReport then ns.ShowBugReport() end end },
                bugClear = { type = "execute", name = "Clear the error log", order = 5, width = "normal", confirm = true,
                    confirmText = "Clear XayaUI's saved Lua errors?",
                    func = function() if ns.ClearErrorLog then ns.ClearErrorLog() end; Notify() end },
            } },
            -- the separate developer addon (XayaUI Dev Assist), reached through its "gameDataProbe" service (Modules.lua contract)
            gameDump = { type = "group", inline = true, name = "Dev Assist (separate tool)", order = 30,
                hidden = function() local svc = ns.Service and ns.Service("gameDataProbe"); return not (svc and type(svc.Open) == "function") end, args = {
                gdText = { type = "description", order = 1, fontSize = "medium",
                    name = "Pulls every class, spec, talent, spell description, spellbook entry, piece of gear, and set-bonus line the game will give an addon, and records which auras each ability you press causes and for how long. It is a separate addon (XayaUI Dev Assist, folder XayaUI_DevAssist) with its own saved-data file, so nothing here touches your rules or profile. Also /xuidev." },
                gdOpen = { type = "execute", name = "Open Dev Assist", order = 2, width = "double",
                    func = function()
                        local svc = ns.Service and ns.Service("gameDataProbe")
                        if svc and type(svc.Open) == "function" then svc.Open()
                        else ns.Print("XayaUI Dev Assist is not loaded. Enable it in the AddOns list, then /reload.") end
                    end },
            } },
            -- (Options 0.6.55; REQUEST-LOG #81, #82) XayaUI Dev Assist's own settings: the game-data probe switch and the detailed debug
            -- record. Its code registers them (ns.RegisterSettingsPage("debugging", ...), XayaUI_DevAssist/DevRecord.lua); without it,
            -- nothing of them exists here.
            devPages = { type = "group", inline = true, name = "Dev Assist settings", order = 31,
                hidden = function() return not (ns.DevAssistOn and ns.DevAssistOn()) end,
                args = ns.BuildSettingsPages and ns.BuildSettingsPages("debugging", Notify) or {} },
        } },
    } }
    for k, v in pairs(dispRows) do page.args.ui.args[k] = v end
    return page
end


local function BuildProfiles(binTab)
    local rulesKind = ns.Share.kinds.rules
    local function ApplyRules(snap, mode, okText)
        local now = ns.Share.Apply(rulesKind, snap, mode, function(c)
            shareMsg = okText(c)
            ns.Print(shareMsg)
            Notify()
        end)
        if not now then shareMsg = "Combat: this will happen as soon as combat ends."; Notify() end
    end
    local PR = ns.Profile
    local function rulesInc() return { rules = profInc.rules, bars = profInc.rules, qol = profInc.rules } end
    ------------------------------------------------------------------ Export
    local e = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "A profile is everything you made in XayaUI. Tick the parts to include, then make the text and paste it to a friend or another account; they paste it under Profiles > Import. Personal things (the Notepad, the Shopping List, other players' names) never go in. A single rule or a group: right-click it in the list and pick Export." },
        exportH = { type = "header", name = "Export", order = 1 },
        gen = { type = "execute", name = "Generate export text", order = 20, width = "double",
            disabled = function() for _, v in pairs(profInc) do if v then return false end end return true end,
            func = function()
                local onlyRules = profInc.rules
                for k, v in pairs(profInc) do if v and k ~= "rules" then onlyRules = false end end
                local txt, err
                if onlyRules then   -- rules alone: the rules string (XUI1), which older XayaUI versions also read
                    txt, err = ns.Share.Encode("rules", ns.Share_SnapshotAll(rulesInc(), backupName))
                else
                    txt, err = ns.Share.Encode("profile", PR.Snapshot(profInc, backupName))
                end
                exportText = txt or ("Could not export: " .. tostring(err))
                Notify()
            end },
        exportBox = { type = "input", name = "Export text  (click, Ctrl+A, Ctrl+C)", order = 21, width = "full", multiline = 6,
            get = function() return exportText end, set = function() end },
        msg = { type = "description", order = 22, width = "full", name = function() return shareMsg end },
        savedH = { type = "header", name = "Backups saved on this computer", order = 30 },
        backupIntro = { type = "description", order = 30.5, width = "full",
            name = "A backup is a copy of your rules and groups, kept inside XayaUI's saved settings on this computer. Loading one can add it to what you have or replace it." },
        saveName = { type = "input", name = "Backup name", order = 31, width = "double",
            get = function() return backupName end, set = function(_, v) backupName = v or "" end },
        savePick = { type = "select", name = "Or pick a backup to overwrite", order = 31.5, width = "double",
            values = function() local v = {}; for _, p in ipairs(ns.Backups()) do v[p.name] = p.name end return v end,
            sorting = function() local o = {}; for _, p in ipairs(ns.Backups()) do o[#o + 1] = p.name end table.sort(o, function(x, y) return tostring(x):lower() < tostring(y):lower() end) return o end,
            get = function() for _, p in ipairs(ns.Backups()) do if p.name == backupName then return p.name end end end,
            set = function(_, v) backupName = v or ""; Notify() end },
        save = { type = "execute", order = 32, width = "double",
            name = function()
                for _, p in ipairs(ns.Backups()) do if p.name == backupName then return "Save and overwrite '" .. backupName .. "'" end end
                return "Save a backup"
            end,
            desc = "Saves a copy of your rules and groups. If the name matches an existing backup, that backup is replaced after you confirm.",
            confirm = function()
                for _, p in ipairs(ns.Backups()) do if p.name == backupName then return true end end
                return false
            end,
            confirmText = "Overwrite this backup with your current rules? Its old contents are lost.",
            func = function()
                local ok, msg = ns.Backup_Save(backupName, { rules = true, bars = true, qol = true })
                shareMsg = ok and ("Backup '" .. backupName .. "' " .. msg .. ".") or ("|cffff5555" .. msg .. "|r")
                Notify()
            end },
    }
    for i, c in ipairs(PR and PR.COMPONENTS or {}) do
        if profInc[c.key] == nil then profInc[c.key] = true end   -- (Options 0.6.80) a registered part starts ticked, as every part did
        e["inc_" .. c.key] = Tog(profInc, c.key, c.label, 1 + i, function() end, { width = "double" })
    end
    -- (Options 0.6.84, P4) the backups are copies of the rules (XayaUI_Rules/RuleShare.lua): left out while XayaUI Rules is off
    if not RulesOn() then e.savedH, e.backupIntro, e.saveName, e.savePick, e.save = nil, nil, nil, nil, nil end
    for idx, p in ipairs(RulesOn() and ns.Backups() or {}) do
        e["p" .. idx] = {
            type = "group", inline = true, order = 40 + idx, name = p.name,
            args = {
                desc = { type = "description", order = 1, width = "full", name = ns.Share_DescribeRules(p.data) },
                add = { type = "execute", name = "Load (add)", order = 2, width = "half",
                    func = function() ApplyRules(ns.Copy(p.data), "add", function(c) return ("Added %d rule(s), %d bar(s), %d QoL box(es)."):format(c.rules, c.bars, c.qol) end) end },
                replace = { type = "execute", name = "Load (replace)", order = 3, width = "half",
                    confirm = true, confirmText = "Replace the included parts of your current setup with this backup?",
                    func = function() ApplyRules(ns.Copy(p.data), "replace", function() return ("Loaded '%s'."):format(p.name) end) end },
                export = { type = "execute", name = "Show export text", order = 4, width = "half",
                    func = function() exportText = ns.Share.Encode("rules", p.data) or ""; Notify() end },
                delete = { type = "execute", name = "Delete", order = 5, width = "half",
                    confirm = true, confirmText = "Delete this backup?",
                    func = function() ns.Backup_Delete(idx); Notify() end },
            },
        }
    end
    ------------------------------------------------------------------ Import
    local function held(key)
        if not importSnap then return false end
        if importDef and importDef.kind == "rules" then return key == "rules" end
        return importDef and importDef.kind == "profile" and importSnap.parts and importSnap.parts[key] ~= nil or false
    end
    local function anyTicked()
        if not importSnap then return false end
        if importDef.kind ~= "profile" then return true end
        for _, v in pairs(importInc) do if v then return true end end
        return false
    end
    local m = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Paste a profile, rules or a theme. It is read as you paste; nothing changes until you press Import. Untick a part to leave it out." },
        importH = { type = "header", name = "Import", order = 1 },
        importBox = { type = "input", name = "Paste the text here, then press Accept", order = 2, width = "full", multiline = 6,
            get = function() return importText end,
            set = function(_, v) importText = v or ""; ParseImport(); Notify() end },
        importInfo = { type = "description", order = 3, width = "full", fontSize = "medium",
            name = function()
                if importErr then return "|cffff5555" .. importErr .. "|r" end
                if importSnap then
                    local nm = (importSnap.name and importSnap.name ~= "") and ("'" .. importSnap.name .. "': ") or ""
                    return "|cff55ff55Readable.|r " .. nm .. importDef.Describe(importSnap)
                end
                return "Nothing pasted yet."
            end },
        partsH = { type = "header", name = "Parts to import", order = 4, hidden = function() return not (importSnap and importDef.kind ~= "theme") end },
        rulesMode = { type = "select", name = "Rules and groups", order = 20, width = "double",
            values = { add = "Add them as a new group of their own", replace = "Replace my rules and groups" },
            sorting = { "add", "replace" },
            hidden = function() return not held("rules") end,
            disabled = function() return importDef and importDef.kind == "profile" and not importInc.rules end,
            get = function() return importRulesMode end, set = function(_, v) importRulesMode = v; Notify() end },
        importGo = { type = "execute", name = "Import", order = 30, width = "half",
            desc = "Imports the ticked parts; settings from a profile replace yours one by one and a reload puts them to work. During combat it waits until combat ends.",
            disabled = function() return not anyTicked() end,
            confirm = function() return importRulesMode == "replace" and held("rules") and (importDef.kind == "rules" or importInc.rules) and true or false end,
            confirmText = "Replace all your rules and groups with the imported ones? Your current ones are removed and do not go to the Recycle Bin: export or back them up first.",
            func = function()
                local snap, def = importSnap, importDef
                local mode
                if def.kind == "rules" then mode = importRulesMode
                elseif def.kind == "profile" then mode = { inc = ns.Copy(importInc), rules = importRulesMode } end
                importSnap, importDef, importText, importInc = nil, nil, "", {}
                local now = ns.Share.Apply(def, snap, mode, function(c)
                    if def.kind == "rules" then
                        shareMsg = ("Imported %d rule(s), %d group(s), %d bar(s), %d QoL box(es)."):format(c.rules, c.folders, c.bars, c.qol)
                    elseif def.kind == "profile" then
                        shareMsg = "Imported: " .. table.concat(c.done or {}, ", ") .. "." .. (c.reload and " Reload to put the imported settings to work." or "")
                    else
                        shareMsg = "Imported " .. def.label .. "."
                    end
                    ns.Print(shareMsg)
                    if ns.MarkDirty then ns.MarkDirty() end
                    Notify()
                end)
                if not now then shareMsg = "Combat: this will happen as soon as combat ends."; Notify() end
            end },
        msg = { type = "description", order = 31, width = "full", name = function() return shareMsg end },
    }
    for i, c in ipairs(PR and PR.COMPONENTS or {}) do
        m["imp_" .. c.key] = Tog(importInc, c.key, c.label, 4 + i, function() Notify() end,
            { width = "double", hidden = function() return not (importDef and importDef.kind == "profile" and held(c.key)) end })
    end
    -- (Options 0.6.80; plan 6.1: Import shows them as "needs XayaUI Chat" and skips them) parts of the pasted profile whose module is not
    -- loaded here: one line each, never imported
    if PR and PR.Missing and importSnap and importDef and importDef.kind == "profile" then
        for i, miss in ipairs(PR.Missing(importSnap)) do
            m["needs_" .. miss.key] = { type = "description", order = 19 + i * 0.01, width = "full", name = "needs " .. miss.title }
        end
    end
    local args = {
        import = { type = "group", name = "Import", order = 1, args = m },
        export = { type = "group", name = "Export", order = 2, args = e },
    }
    if binTab then binTab.order = 3; binTab.hidden = nil; args.bin = binTab end
    -- (Options 0.6.72; UI-25 to UI-27) the Profiles top tab: Import, Export and the Recycle Bin as its sub-tabs
    return { type = "group", name = "Profiles", order = 6, childGroups = "tab", args = args }
end

ns.UI.Refresh = Notify   -- redraw the options window in place (used by the Import window)
function ns.OpenPage(key)
    if key == "drafts" or key == "creator" then   -- Drafts and the Class/Spec Rule Creator are sub-tabs of Rules now, not pages of their own
        if not EditorOn() then return end   -- (P4b) no Rules tab (XayaUI Rules off, or its editor missing): nothing to open
        ns.pageOpen = nil; ns.infoOpen = false
        Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", key == "drafts" and "draftsTab" or "creatorTab")
        return
    end
    ns.pageOpen = nil; ns.infoOpen = false
    Notify()
    local skinned = ns.SkinRows and ns.SkinRows()
    -- (Options 0.6.72; UI-25: the Recycle Bin is a sub-tab of Profiles; Import / Export are its other sub-tabs)
    if key == "recyclebin" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "profiles", "bin"); return end
    if key == "import" or key == "export" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "profiles", key); return end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, (key == "settings" and skinned) and "set" or key)
end
ns.UI.Creator = function() ns.OpenPage("creator") end
-- Settings > UI Options > Rule Creation (the draft settings live there)
function ns.OpenDraftSettings()
    if not EditorOn() then return end   -- (P4b) no Rule Creation tab without the rule editor
    ns.OpenPage("settings")
    local skinned = ns.SkinRows and ns.SkinRows()
    if skinned then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "set", "ui", "rules")
    else pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "settings", "rules") end
end
ns.UI.Drafts = function() ns.OpenPage("drafts") end
ns.UI.RecycleBin = function() ns.OpenPage("recyclebin") end   -- Profiles > Recycle Bin (Options 0.6.72; was a toolbar button)
-- published for XayaUI Dev Assist's walkthroughs (feature addons never reach into ns.UI / ns.Profile directly)
ns.OptionsApi.OpenRecycleBin = ns.UI.RecycleBin
ns.OptionsApi.Profile = ns.Profile   -- Profiles.lua (loaded before this file): components, Snapshot, Held, Apply
-- a page a feature registered (ns.RegisterSettingsPage), by module and key; sub = a tab inside the page. Used through
-- ns.OpenSettingsPage (Modules.lua) by /xui chat settings, /xui data, right-click on a data strip, the Notepad's gear, and more.
function ns.OptionsApi.OpenPage(module, key, ...)
    -- (V26) in combat: one line, and the page opens when combat ends (core Modules.lua ns.CombatLock)
    if ns.InCombatLock and ns.InCombatLock() and not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then
        local n, path = select("#", ...), { ... }
        ns.CombatLock("settings", function() ns.OptionsApi.OpenPage(module, key, unpack(path, 1, n)) end,
            "the settings window can't open during combat. It will open when combat ends.")
        return
    end
    if not (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) then pcall(ns.OptionsApi.Toggle) end
    ns.pageOpen = nil; ns.infoOpen = false
    Notify()
    -- the tab the page is drawn in (a page that moved to another tab, e.g. the Chat Panel to Blizzard UI Reskin, still opens from an
    -- old ("chat", "chatpanel") call); else the module's own tab
    local tab = ns.OptionsApi.pageTab[key] or (ns.SettingsTabOf and ns.SettingsTabOf(module)) or "qol"
    -- ... = deeper path (a part under the page, then a tab inside it); a path that no longer exists falls back to the page itself
    if not (select("#", ...) > 0 and pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, tab, key, ...)) then
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, tab, key)
    end
end
-- (Options 0.6.72; UI-24 "Cog goes") Settings is a top tab; this opens it (no longer a switch that swaps the feature tabs out)
ns.UI.Settings = function() ns.OpenPage("settings") end


-- Explanations (static description rows of 50+ characters) become an info icon: on the section heading above them, or on the title
-- of the inline box they sit in. Descriptions with no heading to attach to (page intros) and dynamic / conditional ones stay put.
function ns.InfoPass(root)
    local seen = {}
    local function ord(a) return tonumber(a and a.order) or 100 end
    local function walk(g)
        if type(g) ~= "table" or seen[g] then return end
        seen[g] = true
        if g.type ~= "group" or type(g.args) ~= "table" then return end
        -- (Options 0.6.69, REQUEST-LOG A15 P-16 click cost) the sort below only decides which heading a long description moves to; a
        -- group with no such description (every rule list: hundreds of rule groups, no descriptions) is left as it is, unsorted. Each
        -- entry's order is read once, not twice per comparison. Same result as before (tests/options_click_cost_run.py, parity).
        local keys, ords, cand = {}, {}, false
        for k, v in pairs(g.args) do
            if type(v) == "table" then
                keys[#keys + 1] = k; ords[k] = ord(v)
                if not cand and v.type == "description" and type(v.name) == "string" and #v.name >= 50 and v.hidden == nil
                    and not (type(v.arg) == "table" and v.arg.xuiKeep) then cand = true end
            end
        end
        if not cand then keys = {} end
        table.sort(keys, function(a, b)
            local oa, ob = ords[a], ords[b]
            if oa ~= ob then return oa < ob end
            return tostring(a) < tostring(b)
        end)
        local lastHeader
        for _, k in ipairs(keys) do
            local v = g.args[k]
            if v.type == "header" and type(v.name) == "string" and v.name ~= "" then
                lastHeader = v
            elseif v.type == "description" and type(v.name) == "string" and #v.name >= 50 and v.hidden == nil
                and not (type(v.arg) == "table" and v.arg.xuiKeep) then
                local owner = lastHeader or ((g.inline and type(g.name) == "string" and g.name ~= "") and g or nil)
                if owner then
                    owner.xuiInfo = owner.xuiInfo and (owner.xuiInfo .. "\n\n" .. v.name) or v.name
                    g.args[k] = nil
                end
            elseif v.type == "group" then
                lastHeader = nil
            end
        end
        for _, v in pairs(g.args) do if type(v) == "table" and v.type == "group" then walk(v) end end
    end
    walk(root)
end
local function BuildOptions()
    ---------------------------------------------------------- Rules (XayaUI_Rules/Editor/RulesTree.lua; P3)
    local track, allQol, allBars
    if EditorOn() then track, allQol, allBars = ns.OptionsApi.RuleEditor.BuildRulesTab() end   -- (P4) none while XayaUI Rules is off (P4b: or its editor is missing)
    -- Recycle Bin (#88; XayaUI/RecycleBin.lua): deleted rules and groups wait here for the chosen time, then go for good.
    local binArgs = {
        keep = { type = "select", order = 1, width = "normal", name = "Keep deleted items for",
            desc = "How long a deleted rule or group stays here before it is removed for good. Checked at login and every 30 minutes; a shorter time that would remove items now asks first.",
            values = function() local v = {}; for _, k in ipairs(ns.RECYCLE_KEEP) do v[k[1]] = k[2] end; return v end,
            sorting = function() local o = {}; for _, k in ipairs(ns.RECYCLE_KEEP) do o[#o + 1] = k[1] end; return o end,
            get = function() return ns.RecycleKeepHours() end,
            -- FA-14 (Options 0.6.69; Xaya: "Ask first (Recommended)"): a shorter time that removes items for good now asks first
            set = function(_, v)
                local n = ns.RecycleWouldPurge and ns.RecycleWouldPurge(v) or 0
                if n == 0 then ns.SetRecycleKeepHours(v); Notify(); return end
                local label = v
                for _, k in ipairs(ns.RECYCLE_KEEP) do if k[1] == v then label = k[2] end end
                StaticPopup_Show("XAYAUI_CONFIRM", ("Keep deleted items for %s? %d item(s) in the Recycle Bin are older than that and will be removed for good now."):format(tostring(label), n),
                    nil, { cb = function() ns.SetRecycleKeepHours(v); Notify() end })
            end },
        empty = { type = "execute", order = 2, width = "normal", name = "Empty Recycle Bin",
            desc = "Removes everything in the Recycle Bin for good.",
            disabled = function() return #ns.RecycleItems() == 0 end,
            confirm = function() return ("Remove all %d item(s) in the Recycle Bin for good? This cannot be undone."):format(#ns.RecycleItems()) end,
            func = function() local n = ns.RecycleEmpty(); ns.Print("Recycle Bin emptied (" .. n .. " item(s) removed for good)."); Notify() end },
    }
    local function binLeft(h)
        if h >= 48 then return ("%d days"):format(math.floor(h / 24)) end
        if h >= 1 then return ("%d hours"):format(math.floor(h)) end
        return "less than an hour"
    end
    local binItems = ns.RecycleItems and ns.RecycleItems() or {}
    binArgs.summary = { type = "description", order = 3, width = "full", fontSize = "medium",
        name = (#binItems == 0) and "\nThe Recycle Bin is empty. Deleted rules and groups, and cues, conditions and triggers removed with the red X, wait here so they can be restored."
            or ("\n%d item(s). Each is removed for good %s after it was deleted."):format(#binItems, ns.RecycleKeepLabel()) }
    for i, it in ipairs(binItems) do
        -- (Options 0.6.80; plan 6.3) what an item is comes from its registered bin kind (core RecycleBin.lua ns.RecycleDescribe); an item
        -- whose module is off reads "(<kind>: module not loaded)" and stays in the bin
        local what = it.what or (ns.RecycleDescribe and ns.RecycleDescribe(it)) or tostring(it.kind)
        binArgs["item" .. i] = { type = "group", inline = true, order = 10 + i, name = tostring(it.name), args = {
            info = { type = "description", order = 1, width = "relative", relWidth = 0.7, fontSize = "medium",
                name = ("%s. Deleted %s; removed for good in %s."):format(what, date("%Y-%m-%d %H:%M", it.deletedAt or 0), binLeft(it.hoursLeft or 0)) },
            restore = { type = "execute", order = 2, width = "relative", relWidth = 0.14, name = "Restore",
                desc = "Puts it back where it was. If its group is gone, it comes back at the top level.",
                func = function()
                    local ok, note = ns.RecycleRestore(it.id)
                    ns.Print(ok and ("Restored '" .. tostring(it.name) .. "'." .. ((note and note ~= "") and (" " .. note .. ".") or "")) or ("Not restored: " .. tostring(note)))
                    if ns.MarkDirty then ns.MarkDirty() end
                    Notify()
                end },
            delete = { type = "execute", order = 3, width = "relative", relWidth = 0.14, name = "Delete now",
                desc = "Removes this item for good.",
                confirm = function() return "Remove '" .. tostring(it.name) .. "' for good? This cannot be undone." end,
                func = function() ns.RecycleDeleteNow(it.id); Notify() end },
        } }
    end
    local binTab = { type = "group", name = "Recycle Bin", order = 3, args = binArgs }   -- a sub-tab of Profiles (Options 0.6.72; UI-25)
    -- QoL Elements (stat boxes, cursor tracker, buff bars) are switched off for now: their files are not in XayaUI.toc, so ns.QoLOn is nil and the tab is skipped.
    -- Feature tabs (Chat, QoL, Bonus Features): left tree, options in the right pane. The entries are sorted alphabetically (see below); the older
    -- QoL Elements entries (stat boxes, cursor tracker, buff bars) come last, and only exist while their files are loaded.
    local minimapGroup = ns.BuildMinimapTab and ns.BuildMinimapTab(Notify) or nil   -- lives in Settings (Xaya, 2026-11-03), not under a feature tab
    -- One top tab per feature addon (Chat, QoL, Bonus Features), built from the pages each registered (Modules.lua:
    -- ns.RegisterSettingsPage). An addon that is switched off registers nothing, so its tab is simply absent.
    local modTabs = ns.OptionsApi.ModuleTabs(Notify, ns.QoLOn and { allqol = allQol, allcursor = (ns.CursorTrackerGroup and ns.CursorTrackerGroup(Notify)) or nil, allbars = allBars } or nil)

    -- Addon Info and Settings > Acknowledgements moved into the version pane (InfoPane.lua, Options 0.6.56; Xaya 2026-11-06: "Both
    -- move into the pane"): Info > Version info and Info > Credits + Acknowledgements. The version text opens the pane.
    -- Settings (skin on): the last top tab (Options 0.6.72; UI-24 "Cog goes": before, a toolbar cog swapped the feature tabs out for it):
    --   Settings page = left sidebar: UI Options (Display | Rule Creation | Theme tabs), Minimap Button, Debugging
    local function SettingsOn() return (ns.SkinRows and ns.SkinRows()) and true or false end
    local settings = BuildAddonSettings()
    local sa = settings.args
    local dispArgs = {}
    for k, v in pairs(sa.ui.args) do dispArgs[k] = v end
    dispArgs.intro = sa.intro
    local setUi = { type = "group", name = "UI Options", order = 1, childGroups = "tab", args = {
        display = { type = "group", name = "Display", order = 1, args = dispArgs },
        rules = sa.rules and { type = "group", name = "Rule Creation", order = 1.5, args = sa.rules.args } or nil,   -- (P4) none while XayaUI Rules is off
        theme = { type = "group", name = "Theme", order = 2, args = sa.theme.args },
    } }
    local setDbg = { type = "group", name = "Debugging", order = 2, args = sa.debug.args }
    -- one top-level page with a left sidebar like the rest of the addon (UI Options, Debugging), instead of two top tabs (Xaya, 2026-11-02)
    local setPage = { type = "group", name = "Settings", order = 7, childGroups = "tree", hidden = function() return not SettingsOn() end,
        args = { ui = setUi, minimap = minimapGroup, debug = setDbg } }
    if minimapGroup then
        minimapGroup.order = 1.5
        settings.args.minimap = minimapGroup   -- the old single Settings tab (skin rows off) gets it too
    end
    settings.hidden = function() return ns.SkinRows and ns.SkinRows() and true or false end   -- skin off: the old single Settings tab
    -- (Options 0.6.72) the Rules and feature tabs stay beside Settings (they went away while the Settings pages were open, 2026-11-01)
    -- The Game Menu look (XayaUI_Reskin) was on this Display page until Options 0.6.38; it is the Esc Menu page of the Blizzard UI
    -- Reskin tab now (module "reskin", with the Chat Panel and the Character Pane). The XayaUI button in that menu stays here (it adds
    -- a button, it does not restyle the menu); one line says where the look went.
    if modTabs.reskin and modTabs.reskin.args and modTabs.reskin.args.gamemenu then
        dispArgs.gm_moved = { type = "description", order = 24.2, width = "full", arg = { xuiKeep = true },   -- shown, not folded into an (i)
            name = "The Esc menu's own look (the XayaUI skin) is under the Blizzard Reskin tab > Esc Menu." }
    end
    local out = { type = "group", name = "XayaUI", childGroups = "tab",
        args = { cooldowns = track, chat = modTabs.chat, qol = modTabs.qol, bonus = modTabs.bonus, reskin = modTabs.reskin, profiles = BuildProfiles(binTab), settings = settings, set = setPage } }
    pcall(RE.SmartOpen)
    pcall(ns.FeatureTreesOpen)
    pcall(RE.ApplyTreeFilter, out)
    if ns.SkinRows and ns.SkinRows() then pcall(ns.InfoPass, out) end   -- the info icons are part of the skin
    pcall(ns.OptionsApi.HalfInputs, out)
    return out
end
-- (Options 0.6.69, REQUEST-LOG A15 P-16 click cost) While one build of the tree or one redraw of the sidebar rows runs, the rule list
-- does not change, so a rule's cues (and a cue's parent, below) are looked up from one pass over the rules instead of a pass per call (ns.CuesOf outside the
-- engine step reads every rule: with 313 rules, asked for every rule, that was a fifth of a click). The lookup gives the same list,
-- in the same order, as ns.CuesOf, and a new copy each time (a caller may change its copy). Only for the length of that one call:
-- ns.CuesOf is put back after it, even on an error; nested calls share the outer one; inside an engine step the step index answers.
function ns.OptionsApi.WithCueMemo(fn, ...)
    local orig = ns.CuesOf
    if ns.OptionsApi.cueMemoOn or type(orig) ~= "function" or (ns.InStep and ns.InStep()) then return fn(...) end
    local map
    local function memo(p)
        if type(p) ~= "table" or type(p.uid) ~= "string" then return orig(p) end
        if not map then
            map = {}
            for _, r in ipairs(ns.rules or {}) do
                local pu = r.parentUid
                if r.isCue and type(pu) == "string" then
                    local l = map[pu]
                    if not l then l = {}; map[pu] = l end
                    l[#l + 1] = r
                end
            end
        end
        local out, l = {}, map[p.uid]
        if l then for i = 1, #l do if l[i] ~= p then out[#out + 1] = l[i] end end end
        return out
    end
    -- the same for a cue's / condition's parent rule (ns.FindParentRule: the first rule in list order with that uid and no parent of
    -- its own; outside a step it reads every rule, and the sidebar's up / down arrows asked it for every rule, for every row)
    local origP, pmap = ns.FindParentRule, nil
    local function memoP(rule)
        if type(rule) ~= "table" then return origP(rule) end
        local uid = rule.parentUid
        if type(uid) ~= "string" or uid == "" then return nil end
        if not pmap then
            pmap = {}
            for _, r in ipairs(ns.rules or {}) do
                if not r.parentUid and type(r.uid) == "string" and pmap[r.uid] == nil then pmap[r.uid] = r end
            end
        end
        return pmap[uid]
    end
    ns.OptionsApi.cueMemoOn = true
    ns.OptionsApi.memo = {}   -- per-pass answers other code may keep for the length of this call (Siblings, the sidebar arrows)
    ns.CuesOf = memo
    if type(origP) == "function" then ns.FindParentRule = memoP end
    local res = { pcall(fn, ...) }
    if ns.CuesOf == memo then ns.CuesOf = orig end
    if ns.FindParentRule == memoP then ns.FindParentRule = origP end
    ns.OptionsApi.cueMemoOn = nil
    ns.OptionsApi.memo = nil
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end
ns.BuildOptionsTable = function(...) return ns.OptionsApi.WithCueMemo(BuildOptions, ...) end
-- (Options 0.6.63; REQUEST-LOG UI-47 / UI-48, her answer for text inputs: "Half width, two per row") every one-line text input that
-- would take a whole row or most of it (width "full", none given, or "double": 340 px, the Shopping List's "Enchant: Head" in her
-- screenshot) is half the row (AceConfigDialog's relative width; 0.49 so two fit beside the
-- gap). Multi-line boxes stay full width; an input drawn by its own widget (dialogControl: the spell search and the like) keeps its own
-- size (a session choice, listed in docs/design/DISPLAY-RULES.md for her look).
function ns.OptionsApi.HalfInputs(t, depth)
    depth = depth or 0
    if type(t) ~= "table" or depth > 14 then return end
    for _, o in pairs(type(t.args) == "table" and t.args or {}) do
        if type(o) == "table" then
            if o.type == "input" and not o.multiline and not o.dialogControl and (o.width == nil or o.width == "full" or o.width == "double") then
                o.width, o.relWidth = "relative", 0.49
            elseif o.type == "group" then
                ns.OptionsApi.HalfInputs(o, depth + 1)
            end
        end
    end
end

-- skipValidation: the options tree is very large (every rule repeats in several lists); Ace's one-off type check of it can exceed
-- the game's script time limit ("script ran too long") when the window first opens.
-- Tree.Get: the tree drawn last when a switch asked for it to be reused (Tree.Keep, top of this file), else a fresh build.
AceConfigRegistry:RegisterOptionsTable(APP, Tree.Get, true)
AceConfigDialog:SetDefaultSize(APP, 780, 860)   -- tall rectangle

-- anything outside the window that changed settings asks for a redraw (Modules.lua section 6). "view": only a switch's state
-- changed (the console window opened or closed), nothing in the tree, so the redraw reuses it (Tree.ViewChanged).
-- (A23 SD-12) closed: nothing to redraw (the next opening builds the tree afresh), so the listener returns at once
ns.On("CONFIG_CHANGED", function(what)
    if not Tree.openFrame then return end
    if what == "view" then Tree.ViewChanged() else Notify() end
end)


local firstOpen = true
function ns.OptionsApi.Toggle()
    ns.OptionsApi.LoadRuleEditor()   -- (P4b) once per session; already done by core's ns.LoadOptions in the usual case
    if RulesOn() and not ns.rules then ns.Print("saved data is not ready yet (rules table is nil).") return end   -- (P4: only while XayaUI Rules is on)
    if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP] then
        AceConfigDialog:Close(APP)
    elseif ns.InCombatLock and ns.InCombatLock() then
        -- (V26) never opens in combat: one line, and it opens when combat ends (core Modules.lua ns.CombatLock; closing is never held back)
        ns.CombatLock("settings", function() if not ns.OptionsApi.IsOpen() then ns.OptionsApi.Toggle() end end,
            "the settings window can't open during combat. It will open when combat ends.")
    else
        -- (Options 0.6.68, REQUEST-LOG A15 P-16: her first open made 3 full builds, 2603 + 739 + 650 ms) The first opening picks the
        -- Rules sub-tab BEFORE the window opens: SelectGroup builds the tree once and only asks for a redraw; Open then reuses that same
        -- tree (Tree.keep) and the redraw SelectGroup asked for is dropped (Open has just drawn it). One build instead of three.
        if firstOpen and not EditorOn() then firstOpen = false end   -- (P4) no Rules tab: the window opens on its first tab
        if RE.FixSelection then pcall(RE.FixSelection) end   -- (A23 SD-12) a selected rule that changed list while the window was closed
        if firstOpen then
            firstOpen = false
            local ui = PlatS.ui
            local sub = ui and ui.rulesSub
            if sub ~= "smartTab" and sub ~= "draftsTab" and sub ~= "disabledTab" and sub ~= "creatorTab" then sub = "enabledTab" end   -- the last sub-tab used
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", sub)
            Tree.keep = Tree.last and true or nil
        end
        local ok, err = pcall(AceConfigDialog.Open, AceConfigDialog, APP)
        Tree.keep = nil
        Tree.DropPending()
        if not ok then ns.Print("could not open the window: " .. tostring(err)) return end
    end
end
-- Window strata: AceGUI opens its frame at FULLSCREEN_DIALOG, which covers Blizzard dialogs / alert boxes (StaticPopups are DIALOG).
-- Drop the options window to HIGH (still above the HUD and unlocked displays) so an alert box always shows over it. XayaUI's own
-- popups and menus set TOOLTIP strata themselves, so they stay above the window. (do-block: this chunk is near Lua's 200-local limit)
do
    local function LowerWindow()
        local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
        if of and of.frame and of.frame.SetFrameStrata then pcall(of.frame.SetFrameStrata, of.frame, "HIGH") end
    end
    ns.LowerWindowStrata = LowerWindow
    if hooksecurefunc then
        hooksecurefunc(AceConfigDialog, "Open", function(_, app)
            if app ~= APP then return end
            -- (A23 SD-12) the frame XayaUI's window is in while it is open (AceGUI's frames are shared): every lasting hook of this
            -- addon and the rule editor returns at once while this is nil (Tree.Closed clears it)
            do local of0 = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]; Tree.openFrame = of0 and of0.frame or nil end
            -- (Options 0.6.68, A15 P-16: a switch made two full builds, 616 + 739 ms) AceConfigDialog redraws the window itself right
            -- after a control's set (a full Open); a redraw the set asked for (Notify -> NotifyChange, next frame) would build it again
            Tree.DropPending()
            LowerWindow()
            if not ns.paneSizeApplied then ns.paneSizeApplied = true; if ns.ApplyPaneSize then pcall(ns.ApplyPaneSize) end end   -- saved size override, once per session
            if RE.DraftsOnOpen then pcall(RE.DraftsOnOpen) end   -- remember every rule's saved version
            if Tree.DriverStart then Tree.DriverStart() end   -- the window's driver runs while it is open, never while closed (V14)
            local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
            if of and of.frame and not of.frame.xuiDraftHook then   -- window closed (button, Esc, toggle): unsaved rules go to Drafts
                of.frame.xuiDraftHook = true
                of.frame:HookScript("OnHide", function(self)
                    if self ~= Tree.openFrame then return end   -- (A23 SD-12) the frame went to another addon: its window closed, not XayaUI's
                    if RE.DraftsOnClose then pcall(RE.DraftsOnClose) end
                    if RE.SearchOnClose then pcall(RE.SearchOnClose) end   -- free the search indexes, stop their scans (Options 0.6.37)
                    if Tree.Closed then pcall(Tree.Closed) end   -- stop the driver; clear previews, the kept tree, the strips (Options 0.6.41)
                end)
            end
        end)
        -- every pane the window builds (an opening, a redraw, a click on a row): with "Use drafts" off the rule shown gets its first
        -- undo state here, before it can be edited (Drafts.lua ns.UndoFirstState; Options 0.6.41, instead of copying every rule)
        hooksecurefunc(AceConfigDialog, "FeedGroup", function(_, app)
            if app ~= APP then return end   -- (A23 SD-12) another addon's window
            Tree.decorateDue = true   -- a pane was drawn (a tab or row click): the next tick decorates it
            if RE.UndoFirstState then pcall(RE.UndoFirstState) end
        end)
        -- any widget made (a dropdown's list, a pane's controls, a scrolled-in row): the next tick decorates it (Options 0.6.68)
        local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
        -- (A23 SD-12) only while the window is open (another addon's window makes widgets too)
        if AceGUI and AceGUI.Create then hooksecurefunc(AceGUI, "Create", function() if Tree.openFrame then Tree.decorateDue = true end end) end
    end
end
ns.optionsLoaded = true

-------------------------------------------------------------------------------
-- Debug console tray (attached under the window)
-------------------------------------------------------------------------------
local HEADER_H, BODY_H = 24, 190
local tray

local function TrayOpen()
    return not (PlatS.ui) or PlatS.ui.trayOpen ~= false
end

local function ApplyTrayState()
    if not tray then return end
    local open = TrayOpen()
    tray:SetHeight(open and (HEADER_H + BODY_H) or HEADER_H)
    tray.status:SetShown(open)
    tray.log:SetShown(open)
    tray.check:SetChecked(open)
end

local function BuildTray()
    local t = CreateFrame("Frame", "CueRulesTray", UIParent, "BackdropTemplate")
    t:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    t:SetBackdropColor(0.06, 0.06, 0.07, 0.96)
    t:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)

    t.check = CreateFrame("CheckButton", nil, t, "UICheckButtonTemplate")
    t.check:SetSize(22, 22)
    t.check:SetPoint("TOPLEFT", 6, -1)
    t.check.text = t.check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.check.text:SetPoint("LEFT", t.check, "RIGHT", 2, 0)
    t.check.text:SetText("Debug console")
    t.check:SetScript("OnClick", function(self)
        PlatS.ui = PlatS.ui or {}
        PlatS.ui.trayOpen = self:GetChecked() and true or false
        ApplyTrayState()
    end)

    t.clear = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
    t.clear:SetSize(56, 18)
    t.clear:SetPoint("TOPRIGHT", -6, -3)
    t.clear:SetText("Clear")
    t.clear:SetScript("OnClick", function() t.log:Clear(); if ns.logBuf then wipe(ns.logBuf) end end)
    ns.FlatButton(t.clear)

    t.copy = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
    t.copy:SetSize(56, 18)
    t.copy:SetPoint("RIGHT", t.clear, "LEFT", -4, 0)
    t.copy:SetText("Copy")
    t.copy:SetScript("OnClick", function() if ns.CopyConsole then ns.CopyConsole() end end)
    ns.FlatButton(t.copy)

    t.status = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.status:SetPoint("TOPLEFT", 10, -(HEADER_H + 4))
    t.status:SetPoint("TOPRIGHT", -10, -(HEADER_H + 4))
    t.status:SetJustifyH("LEFT")
    t.status:SetJustifyV("TOP")
    t.status:SetHeight(84)

    t.log = CreateFrame("ScrollingMessageFrame", nil, t)
    t.log:SetPoint("TOPLEFT", 10, -(HEADER_H + 92))
    t.log:SetPoint("BOTTOMRIGHT", -10, 8)
    t.log:SetFontObject(GameFontHighlightSmall)
    t.log:SetJustifyH("LEFT")
    t.log:SetMaxLines(300)
    t.log:SetFading(false)
    t.log:SetInsertMode("BOTTOM")
    t.log:EnableMouseWheel(true)
    t.log:SetScript("OnMouseWheel", function(self, d) if d > 0 then self:ScrollUp() else self:ScrollDown() end end)
    for _, line in ipairs(ns.logBuf or {}) do t.log:AddMessage(line) end
    Tree.trayDrawn = ns.logSerial or 0   -- (core Core.lua counts every line put in ns.logBuf)
    return t
end

-- A log line is drawn into the strip only while the strip is shown (V14, Options 0.6.41): hidden (the window closed, or "Show the
-- debug console" off) it draws nothing, and when it is shown again it draws the lines of ns.logBuf it missed (Tree.TrayCatchUp).
-- Private lines (ns.PrintPrivate, never in ns.logBuf) that come while it is hidden are not drawn later, as before the strip is built.
ns.On("LOG", function(line)
    if not (tray and tray:IsShown()) then return end
    tray.log:AddMessage(line)
    Tree.trayDrawn = ns.logSerial or 0
end)
-- (core Core.lua ns.LogWanted: rule and snapshot lines are built only while the strip, the console window or the record can take them)
function ns.LogTrayOn() return (tray and tray:IsShown()) and true or false end
function Tree.TrayCatchUp()
    local now, buf = ns.logSerial or 0, ns.logBuf or {}
    local n = #buf
    local missed = math.min(now - (Tree.trayDrawn or now), n)
    for i = n - missed + 1, n do tray.log:AddMessage(buf[i]) end
    Tree.trayDrawn = now
end
do
    -- /xui debug perf: trace of what happens after a click, in FRAMES. Anything that lands on a later frame than the click is a visible
    -- intermediate state (the cause of a blink), so the trace shows exactly which step is late.
    -- The frame counter runs only while tracing is on (V14, Options 0.6.41; it counted every frame from the first opening before).
    local fno, fclick = 0, 0
    local tf
    function ns.Trace(tag)
        if not (ns.perf and ns.perf.show) then return end
        tf = tf or CreateFrame("Frame")
        if not tf:GetScript("OnUpdate") then
            tf:SetScript("OnUpdate", function(self)
                if not (ns.perf and ns.perf.show) then self:SetScript("OnUpdate", nil) return end   -- /xui debug perf off: the counter stops
                fno = fno + 1
            end)
        end
        if tag == "click" then fclick = fno end
        print(string.format("|cffffd100XayaUI|r trace +%d frame(s): %s", fno - fclick, tag))
    end
    ns.origOpen = AceConfigDialog.Open
    AceConfigDialog.Open = function(self, app, ...)
        if app ~= APP then return ns.origOpen(self, app, ...) end   -- (A23 SD-12) other addons' windows: straight through, first
        ns.Trace("Open (full window rebuild)")
        local t0 = debugprofilestop and debugprofilestop() or 0
        local a, b, c = ns.origOpen(self, app, ...)
        local t1 = debugprofilestop and debugprofilestop() or 0
        pcall(ns.DecorateTrees, nil, true); Tree.decorateDue = false   -- (decorated: nothing new to catch on the next tick; true: a rebuild, TreePaint.lua KeepScroll)
        if debugprofilestop then
            local t2 = debugprofilestop()
            ns.perf = ns.perf or { n = 0 }
            ns.perf.n = ns.perf.n + 1; ns.perf.build, ns.perf.skin = t1 - t0, t2 - t1
            if ns.perf.show then print(string.format("|cffffd100XayaUI|r rebuild #%d: build %.0f ms + skin %.0f ms", ns.perf.n, t1 - t0, t2 - t1)) end
        end
        return a, b, c
    end
end
-- (P3) the rule selected in the Rules sidebar and its live status line come from the rule editor (XayaUI_Rules/Editor/Sidebar.lua, Editor.lua)
-- (P4b) nil while the rule editor is not loaded (XayaUI Rules off): the strip then reads as with no rule selected
local function SelectedRule() local f = ns.OptionsApi.RuleEditor.SelectedRule; return f and f() end
local function StatusText(rule) return ns.OptionsApi.RuleEditor.StatusText(rule) end

local ARROW_OPEN, ARROW_COLLAPSED = "Interface\\Buttons\\Arrow-Up-Up", "Interface\\Buttons\\Arrow-Down-Up"

-- the title-bar buttons' places: X at the right edge, the collapse arrow just left of it (the ? follows the arrow). #478 (Options 0.6.97,
-- Xaya 2026-11-07, collapsed: "? and the collapse button now sit just left of the 'XayaUI' title and X just right of it ... Expected:
-- the same positions as when open, at the right edge"): the same anchors in both states (the collapsed window keeps its full width).
local function AnchorTitleButtons(c, fr)
    c.close:ClearAllPoints()
    c.close:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -6, -4)
    c.arrow:ClearAllPoints()
    c.arrow:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -32, -4)
end

-- (V26; round-3 review) the rules-off line (EnsureChrome builds it as c.off). Shown while rules are off (/xui disable) and the window is
-- open and not collapsed. Synced when the window opens, on the driver's pass while it is open (one flag compared), when it is expanded,
-- and at once on RULES_DISABLED / RULES_ENABLED (below; they return at their first line while the window is closed, A23 SD-12).
Tree.RULES_OFF_TEXT = "Rules are off. Type /xui enable to turn them back on."
function Tree.SyncRulesOff(of)
    local c = of and of.xuiChrome
    if not (c and c.off) then return end
    local want = (ns.RulesDisabled and c.owned and not c.collapsed) and true or false
    if c.off:IsShown() ~= want then c.off:SetShown(want) end
end
local function RulesSwitched()
    if not Tree.openFrame then return end   -- (A23 SD-12) closed: the line is synced when the window opens
    Tree.SyncRulesOff(AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP])
end
ns.On("RULES_DISABLED", RulesSwitched)
ns.On("RULES_ENABLED", RulesSwitched)
local function SetCollapsed(of, collapsed)
    local c = of and of.xuiChrome
    local fr = of and of.frame
    if not (c and fr) then return end
    collapsed = collapsed and true or false
    if (c.collapsed or false) == collapsed then return end
    c.collapsed = collapsed
    if collapsed then
        c.hidden = {}
        for _, child in ipairs({ fr:GetChildren() }) do
            if child ~= c.title and child ~= c.arrow and child ~= c.close and child ~= c.help and child:IsShown() then
                c.hidden[#c.hidden + 1] = child
                child:Hide()
            end
        end
        fr:SetBackdropColor(0, 0, 0, 0)
        fr:SetBackdropBorderColor(0, 0, 0, 0)
        fr:EnableMouse(false)
        -- #478: the buttons stay where they are when the window is open (until Options 0.6.96 the X moved to the right of the "XayaUI"
        -- title and the arrow, with the ? beside it, to its left)
        AnchorTitleButtons(c, fr)
        c.openWidth = fr:GetWidth()   -- (#478) kept while collapsed: Skin.lua ns.UpdateMinWidth
        c.arrow.tex:SetTexture(ARROW_COLLAPSED)
    else
        for _, child in ipairs(c.hidden or {}) do child:Show() end
        c.hidden = nil
        Tree.SyncRulesOff(of)   -- (V26) rules may have been turned on while it was collapsed
        fr:SetBackdropColor(0, 0, 0, 1)
        fr:SetBackdropBorderColor(1, 1, 1, 1)
        fr:EnableMouse(true)
        AnchorTitleButtons(c, fr)
        c.openWidth = nil
        c.close:Show()
        c.arrow.tex:SetTexture(ARROW_OPEN)
    end
end

local function EnsureChrome(of)
    local fr = of and of.frame
    if not (fr and of.titlebg and of.titletext) then return end
    local c = of.xuiChrome
    if not c then
        c = {}
        of.xuiChrome = c
        c.title = of.titletext:GetParent()

        c.close = CreateFrame("Button", nil, fr, "UIPanelCloseButton")
        c.close:SetSize(22, 22)   -- the title ribbon is 28 px tall (Skin.lua); 22 px buttons centered in it
        c.close:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -6, -4)
        c.close:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.close:SetScript("OnClick", function() AceConfigDialog:Close(APP) end)

        -- boxed button (same skin as the Close button), just left of the X
        c.arrow = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
        c.arrow:SetSize(22, 22)
        c.arrow:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -32, -4)
        c.arrow:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.arrow.tex = c.arrow:CreateTexture(nil, "OVERLAY")
        c.arrow.tex:SetSize(14, 14)
        c.arrow.tex:SetPoint("CENTER", 0, 0)
        c.arrow.tex:SetTexture(ARROW_OPEN)
        c.arrow:SetScript("OnClick", function() SetCollapsed(of, not c.collapsed) end)

        -- ? just left of the collapse arrow (Xaya 2026-11-06: "nest it in the title bar alongside the collapse pane and X close
        -- button"; "help icon brings you to its location wherever its nested"): opens the version pane at Info > Help (FAQ).
        -- Anchored to the arrow, so it follows it beside the banner when the window is collapsed.
        c.help = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
        c.help:SetSize(22, 22)
        c.help:SetPoint("RIGHT", c.arrow, "LEFT", -4, 0)
        c.help:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.help:SetText("?")
        c.help:SetScript("OnClick", function() if ns.InfoPane then ns.InfoPane.OpenHelp() end end)
        c.help:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Help")
            GameTooltip:AddLine("Opens Help (FAQ) in the version pane (Info > Help).", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        c.help:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- #468 (Options 0.6.97): XayaUI's own windows always have the flat button look, whatever Blizzard Reskin > Buttons says (that
        -- switch only restyles Blizzard's windows). The ? and the collapse arrow are XayaUI's own buttons: core's flat look (Core.lua
        -- ns.PaintFlatButton, through ns.SkinPlainButton), painted again each time they show. The arrow's glyph is the button's own
        -- texture, not Blizzard's art, so it is kept visible. The X (UIPanelCloseButton) is not repainted: its X is its art (A5 asks
        -- which red button she meant).
        local function FlatChrome(b)
            if ns.SkinPlainButton then pcall(ns.SkinPlainButton, b, false) end
            if b.tex then b.tex:SetAlpha(1) end
        end
        c.flatChrome = FlatChrome
        FlatChrome(c.arrow); FlatChrome(c.help)
        c.arrow:HookScript("OnShow", FlatChrome); c.help:HookScript("OnShow", FlatChrome)
        c.arrow:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(c.collapsed and "Expand the window" or "Collapse to the banner")
            GameTooltip:Show()
        end)
        c.arrow:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- AceGUI's own status bar (a boxed strip from the bottom-left corner to the Close button) shows nothing in this window:
        -- hidden while XayaUI uses the window, shown again on release (Xaya 2026-11-04: "bottom random bar left of close should be
        -- removed"). AceGUI's Frame widget does not keep it as a field, only its text (AceGUIContainer-Frame.lua: widget.statustext),
        -- so it is found as that text's parent.
        c.statusbg = of.statustext and of.statustext.GetParent and of.statustext:GetParent()
        -- the version in the bottom-left corner (Xaya 2026-11-04: "addon version should be put in the bottom left") is itself the link
        -- to the version pane (Options 0.6.56; until then Addon Info), in the active theme's accent colors (Options 0.6.39; Xaya 2026-11-05: "remove Addon Info button, make the
        -- XayaUI version text clickable instead", "colorize it to active theme colors"). Repainted when the theme changes.
        c.info = CreateFrame("Button", nil, fr)
        c.info:SetHeight(16)
        ns.infoLink = c.info   -- Skin.lua keeps the rule list above this link
        c.info:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", 20, 11)
        c.info:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.ver = c.info:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        c.ver:SetPoint("LEFT", c.info, "LEFT", 0, 0)
        c.info.text = c.ver
        do
            local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
            local okV, v = pcall(get or function() end, ns.name or "XayaUI", "Version")
            c.ver:SetText("XayaUI " .. ((okV and type(v) == "string" and v ~= "") and ("v" .. v) or "(version unknown)"))
        end
        c.info:SetWidth(math.max(40, (c.ver:GetStringWidth() or 0) + 4))   -- the click area is the text
        c.info.Paint = function(self)
            local T = ns.Theme
            local col = T and T.TokCol and T.TokCol(self.hover and "accentText" or "accent", "settings")   -- (#472: the settings window's scope)
            if col then self.text:SetTextColor(col[1], col[2], col[3], 1) else self.text:SetTextColor(0.75, 0.25, 1) end
        end
        c.info:SetScript("OnEnter", function(self)
            self.hover = true; self:Paint()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Patch Notes and Info")
            GameTooltip:AddLine("Opens the version pane: Patch Notes (What's New and every update) and Info (version, readme, help, credits).", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        c.info:SetScript("OnLeave", function(self) self.hover = false; self:Paint(); GameTooltip:Hide() end)
        c.info:Paint()
        c.info:SetScript("OnClick", function() if ns.InfoPane then ns.InfoPane.Open() end end)
        if not ns.infoLinkThemed and ns.Theme and ns.Theme.OnResolve then
            ns.infoLinkThemed = true
            -- (A23 SD-12) closed: nothing to repaint (the link is painted again when the window opens, EnsureChrome below)
            ns.Theme.OnResolve(function() if not Tree.openFrame then return end; local lk = ns.infoLink; if lk and lk.Paint then lk:Paint() end end)
        end

        -- Delete and Ctrl+Z / Ctrl+Y (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s row 56, her words: "WHY DOES THE ADDON KEEP PREVENTING ME
        -- FROM SCREENSHOTTING"): through core's ns.KeyCatch (XayaUI/KeyCatch.lua), which holds only a key the editor used and leaves every
        -- other key, PRINTSCREEN included, to the game, also in combat (this window set the flag by hand only out of combat, so in a fight it
        -- kept every key while it was open). The window is AceGUI's, recycled for other addons: c.keys is switched off on release.
        -- In combat (XayaUI 0.6.85 review; her row 59: "they are just supposed to be baseline supported by the addon") Delete, Ctrl+Z and
        -- Ctrl+Y still work, but only while the game has no binding on that key: the game does not let an addon keep a key back in
        -- combat, so a bound key would do both things (delete a rule AND run her binding). A bound key is then the game's alone and
        -- the editor leaves it (KeyCatch.lua decides; out of combat the editor uses the key and keeps it from the game, as before).
        if not c.keys and ns.KeyCatch then
            c.keys = ns.KeyCatch(fr, function(_, key)
                if not c.owned then return false end
                if key == "DELETE" then return RE.DeleteKey and RE.DeleteKey() or false   -- (P4b) the rule editor's; absent while XayaUI Rules is off
                elseif (key == "Z" or key == "Y") and IsControlKeyDown() and RE.UndoKey then return RE.UndoKey(key == "Y" or IsShiftKeyDown()) and true or false end
                return false
            end)
        end
        -- multi-select delete links (shown only while rules are selected)
        c.delSel = CreateFrame("Button", nil, fr)
        c.delSel:SetHeight(16)
        c.delSel:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", 110, 14)
        c.delSel:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.delSel.text = c.delSel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        c.delSel.text:SetPoint("LEFT", 0, 0); c.delSel.text:SetTextColor(1, 0.3, 0.3)
        c.delSel:SetScript("OnClick", function() if RE.MultiDelete then RE.MultiDelete() end end)
        c.delSel:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Ctrl+click rule rows to select, Shift+click for a range")
            GameTooltip:Show()
        end)
        c.delSel:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c.clr = CreateFrame("Button", nil, fr)
        c.clr:SetHeight(16); c.clr:SetWidth(70)
        c.clr:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.clr.text = c.clr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        c.clr.text:SetPoint("LEFT", 0, 0); c.clr.text:SetText("Clear selection")
        c.clr:SetScript("OnClick", function() if RE.MultiClear then RE.MultiClear() end end)
        c.delSel:Hide(); c.clr:Hide()
        -- (V26; round-3 review) while rules are off (/xui disable) one plain line in the bottom strip, right of the version link, says
        -- so: the editor's previews and the sidebar's movement unlocks show nothing then. Text only: it takes no mouse.
        c.off = CreateFrame("Frame", nil, fr)
        c.off:SetHeight(16)
        c.off:SetPoint("LEFT", c.info, "RIGHT", 16, 0)
        c.off:SetFrameLevel(fr:GetFrameLevel() + 10)
        c.off.text = c.off:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        c.off.text:SetPoint("LEFT", 0, 0)
        c.off.text:SetTextColor(1, 0.5, 0.25)
        c.off.text:SetText(Tree.RULES_OFF_TEXT)
        c.off:SetWidth(math.floor((c.off.text:GetStringWidth() or 0) + 4.5))
        c.off:Hide()

        -- AceGUI recycles Frame widgets: undo everything on release so other addons' windows stay untouched
        local orig = of.OnRelease
        of.OnRelease = function(self, ...)
            if not c.owned then if orig then return orig(self, ...) end return end   -- (A23 SD-12) another addon's window: AceGUI's own release
            c.owned = nil
            if c.keys then c.keys.SetActive(false) end   -- the next addon to get this window gets it without XayaUI's keys
            pcall(RE.SaveRulesSub)
            SetCollapsed(self, false)
            ns.infoOpen = false; ns.pageOpen = nil
            if RE.MultiReset then RE.MultiReset() end   -- (P4b) the rule editor's; absent while XayaUI Rules is off
            c.delSel:Hide(); c.clr:Hide()
            c.info:Hide()
            if c.ver then c.ver:Hide() end
            if c.statusbg then c.statusbg:Show() end   -- the next addon to get this window keeps AceGUI's status bar
            c.close:Hide()
            c.arrow:Hide()
            if c.help then c.help:Hide() end
            if c.off then c.off:Hide() end   -- (V26) the next addon to get this window never shows XayaUI's rules-off line
            if ns.InfoPane then ns.InfoPane.Close() end   -- the pane belongs to the settings window
            if orig then return orig(self, ...) end
        end
    end
    if not c.owned and c.info.Paint then c.info:Paint() end   -- (A23 SD-12) the theme may have changed while the window was closed
    c.owned = true
    if c.keys then c.keys.SetActive(true) end
    c.arrow:Show()
    c.close:Show()
    if c.help then c.help:Show() end
    -- the version link (its text is c.ver) hides with the collapsed window, click area included
    if c.info then c.info:SetShown(not c.collapsed) end
    if c.ver then c.ver:SetShown(not c.collapsed) end
    if c.statusbg and c.statusbg:IsShown() then c.statusbg:Hide() end
    -- first time the window opens in a session: every top-level group / Smart Categories list under Rules, Loaded and Not Loaded starts collapsed
    if not ns.sessionCollapsed and AceConfigDialog.GetStatusTable then
        local anyTab = false
        for _, tk in ipairs({ "enabledTab", "smartTab", "disabledTab" }) do
            local st = AceConfigDialog:GetStatusTable(APP, { "cooldowns", tk })
            if st and st.groups then
                anyTab = true
                for uv, on in pairs(st.groups) do
                    if on and type(uv) == "string" then
                        local _, n = uv:gsub("\001", "\001")
                        if n == 1 then st.groups[uv] = nil end
                    end
                end
            end
        end
        if anyTab then ns.sessionCollapsed = true; Notify() end
    end
    if c.delSel then
        local n = RE.MultiCount and RE.MultiCount() or 0
        if n > 0 and not c.collapsed then
            c.delSel.text:SetText(("Delete %d selected rule%s"):format(n, n == 1 and "" or "s"))
            c.delSel:SetWidth(c.delSel.text:GetStringWidth() + 4)
            c.clr:ClearAllPoints(); c.clr:SetPoint("LEFT", c.delSel, "RIGHT", 12, 0)
            c.delSel:Hide(); c.clr:Hide()   -- bottom-left duplicate removed: the sidebar bar has Delete / Move to / Clear
        else c.delSel:Hide(); c.clr:Hide() end
    end
    Tree.SyncRulesOff(of)
end

-- The debug console strip under the window: shown, placed and filled, or hidden. Run by the driver below every 0.25 s, and at once
-- by the "Show the debug console" switch (ns.UpdateTrayNow; Options 0.6.39), so the strip does not wait for the next tick.
function Tree.PlaceTray(of, fr, sbar)
    if fr and fr:IsShown() and not (of.xuiChrome and of.xuiChrome.collapsed) and ns.DebugConsoleOn() then
        if not tray then tray = BuildTray(); ApplyTrayState() end
        local anc = sbar or fr
        if tray.anchoredTo ~= anc then
            tray:ClearAllPoints()
            tray:SetPoint("TOPLEFT", anc, "BOTTOMLEFT", 0, 0)
            tray:SetPoint("TOPRIGHT", anc, "BOTTOMRIGHT", 0, 0)
            tray.anchoredTo = anc
        end
        tray:SetFrameStrata(fr:GetFrameStrata())
        tray:SetFrameLevel(fr:GetFrameLevel())
        if not tray:IsShown() then Tree.TrayCatchUp() end
        tray:Show()
        if TrayOpen() then
            local r = SelectedRule()
            tray.status:SetText(r and StatusText(r) or "Select a rule on the left to see its live status here.")
        end
    elseif tray then
        tray:Hide()
        tray.anchoredTo = nil
    end
end
function ns.UpdateTrayNow()
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    local fr = of and of.frame
    Tree.PlaceTray(of, fr, fr and fr:IsShown() and RE.SaveBarUpdate and RE.SaveBarUpdate(fr) or nil)
end

-- The window's driver (dresses the window, keeps the strips under it, re-reads which rules are loaded). V14 (Options 0.6.41; Xaya
-- 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to performance cost / demand
-- in any way"): it runs only while the window is open. Tree.DriverStart (the AceConfigDialog.Open hook above) starts it; the window's
-- OnHide hook (same place) runs Tree.Closed, which stops it and does at once what its first pass after a close used to do: clear the
-- sidebar previews, let go of the kept tree, hide the unsaved-changes strip and the debug console strip, remember the Rules sub-tab.
-- Up to 0.6.40 it ran on every frame from the first opening until /reload, with work every 0.25 s while the window was closed.
local driver, acc = CreateFrame("Frame"), 0
local sigAcc = 0
function Tree.Closed()
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    if of and of.frame and of.frame:IsShown() then return end   -- another addon's window (AceGUI reuses frames) hid, not this one
    driver:SetScript("OnUpdate", nil)
    driver:UnregisterEvent("PLAYER_REGEN_DISABLED")   -- (V26) the combat-start close is listened for only while the window is open
    Tree.openFrame = nil   -- (A23 SD-12) every lasting hook returns at once from now on
    if ns.OptionsApi.TreePaint and ns.OptionsApi.TreePaint.ReturnAll then pcall(ns.OptionsApi.TreePaint.ReturnAll) end   -- (A23 SD-12; review R13)
    acc, sigAcc = 0, 0
    Tree.last, Tree.keep, Tree.loadSeen = nil, nil, nil   -- the kept tree (and the load answers seen) are let go
    if ns.SetWindowOpen then ns.SetWindowOpen(false) end
    if ns.ElementWindowShown then ns.ElementWindowShown(false) end   -- (Options 0.6.92; #495) right-click element menus end with the window
    -- previews, the sidebar's movement unlocks, the preview pause and a window-made unlock end with the window (core ns.EndWindowState)
    if ns.EndWindowState then ns.EndWindowState() elseif ns.AnyPreview() then ns.ClearPreview() end
    if RE.SaveRulesSub then pcall(RE.SaveRulesSub) end   -- the open Rules sub-tab, remembered for the next opening
    if RE.SaveBarUpdate then RE.SaveBarUpdate(nil) end
    Tree.PlaceTray(nil, nil, nil)
end
function Tree.Tick(_, e)
    Tree.keep = nil   -- a kept tree is for the redraw in the same call as Tree.Keep(), never a later frame's (top of this file)
    acc = acc + e
    if acc < 0.25 then return end
    acc = 0
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    local fr = of and of.frame
    if not (fr and fr:IsShown()) then Tree.Closed(); return end   -- (closed without the OnHide hook seeing it)
    if RE.SaveRulesSub then pcall(RE.SaveRulesSub) end   -- the open Rules sub-tab, remembered for the next opening
    pcall(EnsureChrome, of)
    -- (Options 0.6.68, A15 P-16) the decorate / skin pass walks every widget and frame of the window: only when something new was drawn
    -- (an AceGUI widget made or a pane fed since the last pass), not every 0.25 s (it ran ~4x a second while the window was open)
    if Tree.decorateDue and ns.DecorateTrees then Tree.decorateDue = false; ns.DecorateTrees(of) end
    if ns.rules then
        sigAcc = sigAcc + 1
        local fighting = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
        if sigAcc >= 4 and not fighting then
            sigAcc = 0
            -- a rule moved between LOADED and NOT LOADED: redraw the lists. Read from what the engine answered this step (rt.info: its
            -- load and talent answers), no new context, table or string (it was ns.ReadContext + every rule's ns.IsLoaded + a string
            -- each second). Rules the engine has no answer for yet ask ns.IsLoaded.
            -- Not in combat (Options 0.6.68, A15 P-16: with the window open every combat start and end rebuilt the whole tree, ~160 MB
            -- each in the stand-in): out of combat the lists are compared with what they showed at the last check, so a rule that loads
            -- only in combat moves nowhere after the fight; the lists may show it in its out-of-combat place during the fight.
            local changed, rt, ctx = false, ns.runtime, nil
            local seen = Tree.loadSeen or {}
            Tree.loadSeen = seen
            for i, r in ipairs(ns.rules) do
                local info = rt and rt[r] and rt[r].info
                local now
                if r.parentUid then now = false   -- (an outcome follows its parent; it has no list row of its own here)
                elseif not r.enabled then now = false
                elseif info and info.ctxOK ~= nil then now = (info.ctxOK == true and info.talentOK == true)
                else ctx = ctx or ns.ReadContext(); now = ns.IsLoaded(r, ctx) and true or false end
                if seen[i] ~= nil and seen[i] ~= now then changed = true end
                seen[i] = now
            end
            for i = #ns.rules + 1, #seen do seen[i] = nil end
            if changed then Notify() end
        end
    end
    local sbar = RE.SaveBarUpdate and RE.SaveBarUpdate(fr)
    Tree.PlaceTray(of, fr, sbar)
end
function Tree.DriverStart()
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    if not Tree.pickerHooked then Tree.WatchPicker() end   -- (V26) once per session
    if of and of.frame and of.frame:IsShown() then driver:RegisterEvent("PLAYER_REGEN_DISABLED") end   -- (V26) only while open
    if of and of.frame and of.frame:IsShown() and ns.SetWindowOpen then ns.SetWindowOpen(true) end
    -- (Options 0.6.92; #495, PS-59) while the window is shown a right-click on a XayaUI element opens its menu (core Modules.lua section 11)
    if of and of.frame and of.frame:IsShown() and ns.ElementWindowShown then ns.ElementWindowShown(true) end
    if of and of.frame and of.frame:IsShown() and not driver:GetScript("OnUpdate") then driver:SetScript("OnUpdate", Tree.Tick) end
end

-- (V26; Xaya 2026-11-10, her answer for a window open when combat starts: "Close, reopen after") At combat start (PLAYER_REGEN_DISABLED,
-- just before the lockdown) the window closes by its normal path (its OnHide hook: unsaved rule edits go to Drafts, the searches stop,
-- the driver stops), the rule editor's popups close with it, and it opens again when combat ends where she was: the tab, sub-tab and
-- selected rule or group with its tab (the window's own selection path, read from AceConfigDialog's status tables before it closes).
-- The rule editor's popups (XayaUI's own frames and dialogs: hiding them is allowed) close too, and so does Blizzard's color picker
-- when a swatch in XayaUI's window opened it (Tree.WatchPicker; another addon's picker is left alone). The version / help pane is
-- XayaUI's and only reads, but it closes with the window (its OnRelease); when it was open it opens again with the window after combat,
-- on the tab and section it showed (InfoPane.lua keeps them; it opens scrolled to the top).
Tree.POPUP_FRAMES = { "XayaUISpellSearch", "XayaUISoundAllDialog", "XayaUIInfoPopup", "XayaUIImportWindow", "XayaUIThemeAsk" }
Tree.POPUP_DIALOGS = { "XAYAUI_CONFIRM", "XAYAUI_RENAME", "XAYAUI_EXPORT", "XAYAUI_GROUP_FIT", "XAYAUI_AP_SAY", "XAYAUI_AP_ALERT" }
-- the selection path the window shows: each level's selected group (a tree level holds its whole "a\001b" path), at most 16 levels
function Tree.WherePath()
    local path = {}
    if not AceConfigDialog.GetStatusTable then return path end
    for _ = 1, 16 do
        local st = AceConfigDialog:GetStatusTable(APP, path)
        local sel = st and st.groups and st.groups.selected
        if type(sel) ~= "string" or sel == "" then break end
        local n0 = #path
        for seg in sel:gmatch("[^\001]+") do path[#path + 1] = seg end
        if #path == n0 then break end
    end
    return path
end
function Tree.Reopen(where)
    if ns.OptionsApi.IsOpen() then return end
    local now = Tree.WherePath()
    local same = #now == #where
    for i = 1, #where do if now[i] ~= where[i] then same = false end end
    -- (only when the path changed while closed: the status tables keep it otherwise, and a select is a second build)
    if not same and #where > 0 then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(where)) end
    ns.OptionsApi.Toggle()   -- (Toggle drops the redraw the select asked for: one build)
end
-- (V26) Blizzard's ColorPickerFrame is shared by every addon. XayaUI notes when the picker opens from a swatch in its own window: the
-- picker shows from inside the swatch's click (AceGUI's ColorPicker widget: ColorSwatch_OnClick), so the frame under the mouse
-- (GetMouseFoci, globals.md) is that swatch; it is XayaUI's when its parent chain reaches XayaUI's open window (INFERENCE: the mouse
-- focus during the click is the clicked button; unverified in game). The OnShow / OnHide hooks are post-hooks (HookScript), placed
-- once when the window first opens; while the window is closed OnShow only clears the note.
function Tree.WatchPicker()
    local P = rawget(_G, "ColorPickerFrame")
    if Tree.pickerHooked or not (P and P.HookScript) then return end
    Tree.pickerHooked = true
    P:HookScript("OnShow", function()
        Tree.pickerOurs = nil
        local win = Tree.openFrame
        if not win then return end   -- (A23 SD-12) the window is closed: not XayaUI's
        local foci = GetMouseFoci and GetMouseFoci()
        if type(foci) ~= "table" then return end
        for _, rg in ipairs(foci) do
            local p = rg
            for _ = 1, 32 do
                if p == nil then break end
                if p == win then Tree.pickerOurs = true; return end
                p = p.GetParent and p:GetParent() or nil
            end
        end
    end)
    P:HookScript("OnHide", function() Tree.pickerOurs = nil end)
end
-- closes the picker only when XayaUI's swatch opened it (out of combat: PLAYER_REGEN_DISABLED comes before the lockdown). Hide is what
-- AceGUI's swatch itself calls on it; the colors picked so far are already in the rule (each change is set as it is made).
function Tree.ClosePicker()
    local P = rawget(_G, "ColorPickerFrame")
    if Tree.pickerOurs and P and P:IsShown() then pcall(P.Hide, P) end
    Tree.pickerOurs = nil
end
function Tree.CombatStart()
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    if not (of and of.frame and of.frame:IsShown()) then return end
    local where = Tree.WherePath()
    local pane = (ns.InfoPane and ns.InfoPane.IsShown and ns.InfoPane.IsShown()) and true or false   -- read before the window closes it
    Tree.ClosePicker()
    for _, n in ipairs(Tree.POPUP_FRAMES) do
        local p = rawget(_G, n)
        if p and p.IsShown and p:IsShown() then pcall(p.Hide, p) end
    end
    if StaticPopup_Hide then for _, w in ipairs(Tree.POPUP_DIALOGS) do pcall(StaticPopup_Hide, w) end end
    -- hidden now, before the lockdown begins (AceConfigDialog:Close waits for the next frame); its OnClose lets the window go as usual
    if of.Hide then pcall(of.Hide, of) else pcall(of.frame.Hide, of.frame) end
    if AceConfigDialog.OpenFrames[APP] then pcall(AceConfigDialog.Close, AceConfigDialog, APP) end
    if Tree.openFrame and Tree.Closed then pcall(Tree.Closed) end   -- (only if the OnHide hook did not see it: unregisters this event)
    ns.Print("the settings window closed because combat started. It will open again where you left it when combat ends.")
    if ns.CombatLockQueue then
        ns.CombatLockQueue("settings", function()
            Tree.Reopen(where)
            if pane and ns.OptionsApi.IsOpen() and ns.InfoPane and not ns.InfoPane.IsShown() then ns.InfoPane.Open() end
        end)
    end
end
driver:SetScript("OnEvent", Tree.CombatStart)

-------------------------------------------------------------------------------
-- Publish what core may call (Modules.lua section 7). The game's Options > AddOns entry and the addon compartment click live in
-- core (Modules.lua) so they work before this addon is loaded.
-------------------------------------------------------------------------------
function ns.OptionsApi.IsOpen() return (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]) and true or false end
-- the tree the window was last drawn from (nil when none is kept): Skin.lua measures its dropdowns from it instead of building another
function ns.OptionsApi.LastTree() return Tree.last end
function ns.OptionsApi.SkinOn() return (ns.SkinRows and ns.SkinRows()) and true or false end
ns.Options = ns.OptionsApi

-- Dev Assist QA walkthroughs (XayaUI_DevAssist/QAWalks-audit-options.lua) reach the editor only through this service: a fresh options
-- tree's node for one rule or one group, and the Drafts page. Read-only helpers; nothing runs until a walkthrough calls them.
do
    local function FindKey(node, key, depth)
        if type(node) ~= "table" or depth > 18 or type(node.args) ~= "table" then return nil end
        if node.args[key] ~= nil then return node.args[key] end
        for _, c in pairs(node.args) do local hit = FindKey(c, key, depth + 1); if hit then return hit end end
    end
    if ns.Provide then ns.Provide("optionsDebug", {
        RuleNode = function(rule)
            for i, r in ipairs(ns.rules or {}) do if r == rule then return FindKey(BuildOptions(), "rule" .. i, 0) end end
        end,
        FolderNode = function(f) return f and FindKey(BuildOptions(), f.id, 0) end,
        Find = function(node, key) return FindKey(node, key, 0) end,
        DraftsPage = function() return RE.BuildDraftsPage and RE.BuildDraftsPage() end,
        IsEditLocked = function(x) return RE.IsEditLocked and RE.IsEditLocked(x) end,
        DraftsEnabled = function() return RE.DraftsEnabled and RE.DraftsEnabled() end,
        DraftDirty = function(r) return RE.DraftDirty and RE.DraftDirty(r) end,
        Notify = function() if ns.UI and ns.UI.Notify then pcall(ns.UI.Notify) end end,
        -- (Options 0.6.106) the whole options tree as the window builds it: the FA-16 spelling walkthrough (QAWalks-audit.lua) reads
        -- every page's and option's name, desc, tip and list entries from it
        Tree = function() return ns.BuildOptionsTable() end,
    }) end
end
