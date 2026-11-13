-------------------------------------------------------------------------------
-- XayaUI_Options/RuleEditor/TreeHelpers.lua : Rule groups (folders), rule paths, the Rules sub-tab and scope helpers, and selection in the Rules sidebar.
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (XayaUI Options depends on it: ## Dependencies: XayaUI)
-- (bundle 1 round 7, REQUEST-LOG A23 SD-57, her words: "editor is an 'options' pane so 3"; V34) This file is part of XayaUI Options
-- (it was XayaUI_Rules/Editor/, read at login with Rules). The game reads it only when the settings window's code loads, after the
-- window's own files (XayaUI_Options.toc). With XayaUI Rules switched off it stops on the next line and builds nothing.
if not (ns.OptionsApi and ns.Service and ns.Service("rules")) then return end   -- (and nothing while the window's code could not load: Options.lua)
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local PlatS, APP, AceConfigDialog = O.PlatS, O.APP, O.AceConfigDialog
ns.OptionsApi.RuleEditorParts = ns.OptionsApi.RuleEditorParts or {}
local P = ns.OptionsApi.RuleEditorParts

-------------------------------------------------------------------------------
-- Rule group
-------------------------------------------------------------------------------
local function FolderById(id)
    for _, f in ipairs(ns.folders or {}) do if f.id == id then return f end end
end
-- folders from the top level down to f (cycle-safe)
local function FolderChain(f)
    local chain, seen = {}, {}
    while f and not seen[f.id] do
        seen[f.id] = true
        table.insert(chain, 1, f)
        f = f.parent and FolderById(f.parent) or nil
    end
    return chain
end
-- is folder fid equal to, or nested anywhere inside, folder ancestorId? (a damaged, looping parent chain stops after FOLDER_DEPTH steps;
-- review R17: was a new table per call)
local FOLDER_DEPTH = 32
local function IsInFolder(fid, ancestorId)
    local f, d = FolderById(fid), 0
    while f and d < FOLDER_DEPTH do
        if f.id == ancestorId then return true end
        f, d = f.parent and FolderById(f.parent) or nil, d + 1
    end
    return false
end
-- the groups by id (the first one with an id wins, as FolderById)
local function FolderMap()
    local m = {}
    for _, f in ipairs(ns.folders or {}) do if f.id ~= nil and m[f.id] == nil then m[f.id] = f end end
    return m
end
-- Every rule in group fid or in a group nested inside it. (review R17) Each group's answer is worked out once per call, not once per
-- rule with a list search per step of its chain: with 60 groups and 600 rules one call took about 56 ms and 4 MB, and a window build
-- made about two per group.
local function FolderRules(fid)
    local l = {}
    if fid == nil then return l end
    local byId, inside = FolderMap(), {}
    for _, r in ipairs(ns.rules or {}) do
        local id = r.folder
        if id ~= nil then
            local yes = inside[id]
            if yes == nil then
                local f, d = byId[id], 0
                yes = false
                while f and d < FOLDER_DEPTH do
                    if f.id == fid then yes = true; break end
                    local known = inside[f.id]
                    if known ~= nil then yes = known; break end
                    f, d = f.parent ~= nil and byId[f.parent] or nil, d + 1
                end
                inside[id] = yes
            end
            if yes then l[#l + 1] = r end
        end
    end
    return l
end
-- (review R17) How many rules each group holds, its nested groups included (n[id] = #FolderRules(id); nil = none), in one pass over
-- the rules: for the window build, which asked FolderRules once or twice per group.
local function FolderRuleCounts()
    local byId, n, stamp = FolderMap(), {}, {}
    for i, r in ipairs(ns.rules or {}) do
        local f, d = r.folder ~= nil and byId[r.folder] or nil, 0
        while f and d < FOLDER_DEPTH and stamp[f.id] ~= i do   -- (stamp: a looping chain counts each group once, as IsInFolder)
            stamp[f.id] = i
            n[f.id] = (n[f.id] or 0) + 1
            f, d = f.parent ~= nil and byId[f.parent] or nil, d + 1
        end
    end
    return n
end
-- The rules of a group without the cues and conditions inside them (audit D42: the group's Enabled box and Enable / Disable All Rules
-- Inside switched a condition the player had turned off back on; the Delete Group confirmation counted cue rows as rules).
local function FolderTopRules(fid)
    local l = {}
    for _, r in ipairs(FolderRules(fid)) do if not r.parentUid then l[#l + 1] = r end end
    return l
end
-- Display / Sound / Hybrid / Advanced Cue Tracking default folders are sub-sections of Smart Categories inside All Rules
function ns.CueTop(c)
    return c and not c.parent and (c.default == "display" or c.default == "sound" or c.default == "hybrid" or c.default == "advanced") and true or false
end
-- Loaded / Not Loaded show only the user's own groups. The default cue categories (Display Cues, Sound Cues, ...) and the cue-type
-- folders directly inside them (Icons, Progress Textures, ...) are not drawn there: rules in them are listed in the group that is left.
function ns.CueTransparent(f)
    if not f then return false end
    if ns.CueTop(f) then return true end
    if f.default == "display" or f.default == "sound" or f.default == "hybrid" or f.default == "advanced" or f.default == "cursor" then return true end
    do   -- a default category that lost its flag (renamed / re-created) is still recognized by its name
        local nm0 = tostring(f.name or ""):lower()
        if not f.parent then
            for _, d in ipairs(ns.DEFAULT_FOLDERS or {}) do if d.name:lower() == nm0 then return true end end
        end
    end
    local p = f.parent and ns.FolderById and ns.FolderById(f.parent)
    if p and ns.CueTop(p) then
        local nm = tostring(f.name or ""):lower()
        for _, c in ipairs(ns.SMART_CATS or {}) do if c.name:lower() == nm then return true end end
        if nm == "sounds" or nm == "sound cues" or nm == "display cues" then return true end
    end
    return false
end
-- Rules sub-tabs (2026-11-01): Rules > Enabled | Smart Categories | Drafts | Disabled | Recycle Bin.
-- Disabled = the rule's enabled box is unticked, or its load mode is "never". Everything else is Enabled and is split into Loaded / Not Loaded.
function ns.RuleDisabled(r) return (not r.enabled) or (r.load and r.load.mode == "never") or false end
function ns.RuleScope(r, ctx)   -- "disabled" | "loaded" | "notloaded"
    if ns.RuleDisabled(r) then return "disabled" end
    return (ctx and ns.IsLoaded(r, ctx)) and "loaded" or "notloaded"
end
function ns.CurrentSub()   -- the open sub-tab under Rules
    if not AceConfigDialog.GetStatusTable then return "enabledTab" end
    local rt = AceConfigDialog:GetStatusTable(APP, { "cooldowns" })
    return (rt and rt.groups and rt.groups.selected) or "enabledTab"
end
function ns.SaveRulesSub()   -- remembered for next time the window opens
    local ui = PlatS.ui
    if ui and AceConfigDialog.GetStatusTable then ui.rulesSub = ns.CurrentSub() end
    if ns.PickerSync then ns.PickerSync() end   -- (0.6.79; #487) the type picker closes once another Rules sub-tab is open or the window is closed
end
function ns.ScopePath(r, ctx)   -- where a rule's row is in the Enabled / Disabled lists
    local sc = ns.RuleScope(r, ctx)
    local p = { "cooldowns", sc == "disabled" and "disabledTab" or "enabledTab", sc }
    local f = r.folder and FolderById(r.folder)
    if f and sc == "disabled" then
        -- the Disabled list is flat: a rule sits directly under its own group, which sits directly under the list (no parent groups)
        if not ns.CueTransparent(f) then p[#p + 1] = f.id end
    elseif f then
        for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then p[#p + 1] = c.id end end
    end
    for idx, rr in ipairs(ns.rules or {}) do if rr == r then p[#p + 1] = "rule" .. idx; break end end
    return unpack(p)
end
-- Smart Categories shows only the types: its root row and the "by type" row are drawn collapsed to nothing (Options.lua DecorateButton),
-- so both must stay open or the type rows would vanish.
function ns.SmartOpen()
    if not AceConfigDialog.GetStatusTable then return end
    local st = AceConfigDialog:GetStatusTable(APP, { "cooldowns", "smartTab" })
    if not st then return end
    st.groups = st.groups or {}
    st.groups.groups = st.groups.groups or {}
    st.groups.groups["all"] = true
    st.groups.groups["all\001smart"] = true
end
-- Where the tree status of the Rules tab lives (selection + which rows are open)
function ns.RulesTreeStatus()
    if not AceConfigDialog.GetStatusTable then return nil end
    local sub = ns.CurrentSub()
    if sub ~= "smartTab" and sub ~= "disabledTab" then sub = "enabledTab" end
    local t = AceConfigDialog:GetStatusTable(APP, { "cooldowns", sub })
    return t and t.groups
end
-- When a rule's loaded state changes while it is selected in Loaded / Not Loaded, its row moves to the other list. Move the selection
-- with it BEFORE the tree is rebuilt, so the editing pane stays open instead of falling back to the first row of the list.
function ns.FixSelection()
    local S = ns.RulesTreeStatus()
    local sel = S and S.selected
    if type(sel) ~= "string" then return end
    local segs = {}
    for seg in sel:gmatch("[^\001]+") do segs[#segs + 1] = seg end
    if segs[1] ~= "loaded" and segs[1] ~= "notloaded" and segs[1] ~= "disabled" then return end
    local rn = tostring(segs[#segs]):match("^rule(%d+)$")
    local r = rn and ns.rules and ns.rules[tonumber(rn)]
    if not r then return end
    local okc, ctx = pcall(ns.ReadContext)
    if not okc then return end
    local now = ns.RuleScope(r, ctx)
    if now == segs[1] then return end
    if now == "disabled" or segs[1] == "disabled" then
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, ns.ScopePath(r, ctx))   -- the rule moved to the other sub-tab: follow it
    else segs[1] = now; S.selected = table.concat(segs, "\001") end
end
-- Select a row after an edit / move WITHOUT touching the sidebar's open / closed state and without leaving the list the user is in.
-- (AceConfigDialog:SelectGroup normally opens every group on the way, which popped All Rules open.) Takes the same path
-- RulePath / FolderPath return.
function ns.SelectKeep(...)
    local args = { ... }
    local S = ns.RulesTreeStatus()
    local open = S and S.groups
    local snap = {}
    if open then for kk, vv in pairs(open) do snap[kk] = vv end end
    local scope = (ns.CurrentSub() == "smartTab") and "all" or (ns.ScopeOfUV and ns.ScopeOfUV(S and S.selected) or "all")
    local lastRule = (args[1] == "cooldowns" and args[2] == "smartTab") and tostring(args[#args]):match("^rule(%d+)$")
    local lr = lastRule and ns.rules and ns.rules[tonumber(lastRule)]
    if lr and (scope == "loaded" or scope == "notloaded" or scope == "disabled") then
        -- a rule asked for by its Smart Categories path (RulePath) while an Enabled / Disabled list is open: its row there is under
        -- its groups, not under a type row, so take the list's own path for it (the type key in that path is not a row there)
        local okc, ctx = pcall(ns.ReadContext)
        args = { ns.ScopePath(lr, okc and ctx or nil) }
    elseif (scope == "loaded" or scope == "notloaded" or scope == "disabled") and args[1] == "cooldowns" and args[2] == "smartTab" and args[3] == "all" then
        local newScope = scope
        local rn = tostring(args[#args]):match("^rule(%d+)$")
        local r = rn and ns.rules and ns.rules[tonumber(rn)]
        if r then
            local okc, ctx = pcall(ns.ReadContext)
            if okc then newScope = ns.RuleScope(r, ctx) end
        end
        local p = { "cooldowns", newScope == "disabled" and "disabledTab" or "enabledTab", newScope }
        for i = 4, #args do
            local a = args[i]
            local f = tostring(a):match("^f%d") and ns.FolderById(a)
            if a ~= "smart" and not (f and ns.CueTransparent(f)) then p[#p + 1] = a end
        end
        if newScope == "disabled" then
            -- the Disabled list is flat: a rule sits directly under its own group, a group directly under the list. Rebuild the
            -- tail from the rule / group itself (the path handed in is the nested Smart Categories one).
            local last = args[#args]
            local keep = {}
            local rn2 = tostring(last):match("^rule(%d+)$")
            if rn2 then
                local r2 = ns.rules and ns.rules[tonumber(rn2)]
                local f2 = r2 and r2.folder and ns.FolderById(r2.folder)
                if f2 and not ns.CueTransparent(f2) then keep[#keep + 1] = f2.id end
                keep[#keep + 1] = last
            elseif ns.DisabledListed and ns.DisabledListed[last] then keep[1] = last end   -- a group the list does not show falls back to the list itself
            p = { p[1], p[2], p[3] }
            for _, k in ipairs(keep) do p[#p + 1] = k end
        end
        args = p
    end
    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(args))
    if open then
        for kk in pairs(open) do if snap[kk] == nil then open[kk] = nil end end   -- close what SelectGroup opened
        for kk, vv in pairs(snap) do open[kk] = vv end
    end
end
local function FolderPath(f)
    local p = { "cooldowns", "smartTab", "all" }
    local chain = FolderChain(f)
    if ns.CueTop(chain[1]) then p[#p + 1] = "smart" end
    for _, c in ipairs(chain) do p[#p + 1] = c.id end
    return unpack(p)
end

-- Which list a sidebar row belongs to: "loaded", "notloaded" or "all" (first path segment under the Rules tab)
function ns.ScopeOfUV(uv)
    local seg = uv and tostring(uv):match("^([^\001]+)")
    return (seg == "notloaded" or seg == "all" or seg == "disabled") and seg or "loaded"
end
function ns.CurrentScope()
    if not AceConfigDialog.GetStatusTable then return "loaded" end
    local g = ns.RulesTreeStatus()
    return ns.ScopeOfUV(g and g.selected)
end
-- A new, still-empty group is listed in the list it was created from (empty groups default to Loaded)
function ns.PlaceNewGroup(f, scope)
    f.xuiScope = (scope == "notloaded" or scope == "disabled") and scope or nil
    local root = (scope == "notloaded" or scope == "all" or scope == "disabled") and scope or "loaded"
    local p = { "cooldowns", (root == "all") and "smartTab" or (root == "disabled" and "disabledTab" or "enabledTab"), root }
    local chain = FolderChain(f)
    if root == "all" and ns.CueTop(chain[1]) then p[#p + 1] = "smart" end
    if root == "disabled" then
        if not ns.CueTransparent(f) then p[#p + 1] = f.id end   -- the Disabled list is flat: the group sits directly under the list
        return unpack(p)
    end
    for _, c in ipairs(chain) do if root == "all" or not ns.CueTransparent(c) then p[#p + 1] = c.id end end
    return unpack(p)
end
-- Same group, reached through the Loaded list (new groups open here so they show highlighted under Loaded)
function ns.FolderLoadedPath(f)
    local p = { "cooldowns", "enabledTab", "loaded" }
    for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then p[#p + 1] = c.id end end
    return unpack(p)
end

-- The built-in category folders (Display Cues, Sound Cues, ...) are Smart Categories' territory: nothing may be placed into them by hand.
function ns.IsCategoryRoot(f) return f and f.default ~= nil and not f.parent end

local function FolderValues()
    -- depth-first: every group is listed right under its parent, indented one step per level; category buckets and cue-type
    -- folders are never listed (their children are shown as if they sat one level up)
    local v, o = { none = "(none - top level)" }, { "none" }
    local kids = {}
    for _, f in ipairs(ns.folders or {}) do
        local p = f.parent or false
        kids[p] = kids[p] or {}
        kids[p][#kids[p] + 1] = f
    end
    local seen = {}
    local function walk(pid, depth)
        for _, f in ipairs(kids[pid] or {}) do
            if not seen[f.id] then
                seen[f.id] = true
                local hidden = ns.IsCategoryRoot(f) or ns.CueTransparent(f)
                if not hidden then
                    v[f.id] = string.rep("      ", depth) .. (depth > 0 and "|cff888888-|r " or "") .. tostring(f.name)
                    o[#o + 1] = f.id
                end
                walk(f.id, hidden and depth or depth + 1)
            end
        end
    end
    walk(false, 0)
    return v, o
end

-- Which top tab is open now ("cooldowns" = Rules, "smartcat" = Smart Categories ...), and "go back to where I was".
function ns.CurrentTab()   -- "smartcat" stands for Rules > Smart Categories, "cooldowns" for the Enabled / Disabled lists
    local root = AceConfigDialog.GetStatusTable and AceConfigDialog:GetStatusTable(APP)
    local top = root and root.groups and root.groups.selected
    if top == "cooldowns" and ns.CurrentSub() == "smartTab" then return "smartcat" end
    return top
end
function ns.GoHome(tab)
    tab = tab or ns.CurrentTab()
    if tab == "cooldowns" then pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "enabledTab", "loaded")
    else pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "smartTab", "all") end
end
-- (0.6.82; request log row 20, Xaya 2026-11-08: "deleting auras shifts the rule sidebar up still") After a delete the list goes back
-- to its top row, and the window rebuild that follows re-selects that row through AceGUI's TreeGroup:Select, which scrolls the
-- selected row into view: the list jumped to Loaded at the top. A delete keeps the list where it was instead: the scroll position is
-- left on the tree's status table (xuiKeepScroll), and XayaUI_Options (TreePaint.lua, after the rebuild) puts it back and drops the
-- scroll-to-selection. Rows above the deleted one keep their place, the next row moves up into its place; a list now shorter than the
-- view is held at its bottom by AceGUI's own clamp.
-- The top row is the one of the list the delete was made in: Rules > Enabled goes back to LOADED (Loaded and Not Loaded are one list,
-- one sub-tab), Rules > Disabled to DISABLED, Smart Categories to All. Before (review of the row 20 fix): GoHome knows only Enabled and
-- Smart Categories, so a delete made in Rules > Disabled opened Enabled > Loaded at the top.
function ns.GoHomeKeepScroll(tab)
    tab = tab or ns.CurrentTab()
    local S = ns.RulesTreeStatus()
    local sub = ns.CurrentSub()
    if tab == "cooldowns" and sub == "disabledTab" then
        if S then S.xuiKeepScroll = S.scrollvalue or 0 end
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "cooldowns", "disabledTab", "disabled")
        return
    end
    local dest = (tab == "cooldowns") and "enabledTab" or "smartTab"
    if S and sub == dest then S.xuiKeepScroll = S.scrollvalue or 0 end
    ns.GoHome(tab)
end

-- The extra aura IDs of one aura trigger (the built-in Buff / Aura's rule.buffAlt, a "Buff / Aura (another)" row's alt): numbers above 0,
-- no repeats, never the trigger's own aura (mainID), at most ns.AURA_ALT_MAX. Each further argument is a list of IDs (numbers or digit
-- strings) or a text ("123, 456"); they are read in order. Returns the list (nil when it is empty) and how many new IDs did not fit.
-- The one place that builds such a list in the editor: the Trigger tab's boxes (Editor.lua, TriggersEditor.lua) and Merge N Selected
-- (Sidebar.lua) all use it. (XayaUI_Rules/Triggers.lua NormalizeExtra keeps its own copy: that addon loads without this one.)
ns.AURA_ALT_MAX = 30
function ns.AuraIDList(mainID, ...)
    local out, seen, over = {}, { [tonumber(mainID) or 0] = true }, 0
    local function add(v)
        local id = tonumber(v)
        if not id or id <= 0 or seen[id] then return end
        seen[id] = true
        if #out < ns.AURA_ALT_MAX then out[#out + 1] = id else over = over + 1 end
    end
    for i = 1, select("#", ...) do
        local src = select(i, ...)
        if type(src) == "table" then for _, v in ipairs(src) do add(v) end
        elseif type(src) == "string" then for n in src:gmatch("%d+") do add(n) end
        elseif src ~= nil then add(src) end
    end
    return (#out > 0) and out or nil, over
end

local function RulePath(rule)
    for idx, r in ipairs(ns.rules) do
        if r == rule then
            -- Smart Categories lists a rule under each type it matches (the tree has no folder rows there)
            if ns.pickOrigin ~= "cooldowns" then
                for _, c in ipairs(ns.SMART_CATS) do
                    if ns.SmartMatch(r, c.key) then return "cooldowns", "smartTab", "all", "smart", c.key, "rule" .. idx end
                end
            end
            -- no display type: it lives in Loaded / Not Loaded, nested under its (non-transparent) groups
            local okc, ctx = pcall(ns.ReadContext)
            return ns.ScopePath(r, okc and ctx or nil)
        end
    end
    return "cooldowns", "smartTab", "all"
end

-- Keep the editing pane open on a rule after its list row may have moved or vanished. A rule's row in Smart Categories comes from
-- its cues, so deleting its last cue of a type removes the row it was selected through; without this the pane falls back to another page.
function ns.ReselectRule(rule)
    if not rule then return end
    pcall(function()
        local S = ns.RulesTreeStatus()
        local oldSel = S and S.selected
        local sub = ns.CurrentSub()
        if sub ~= "smartTab" and sub ~= "disabledTab" then sub = "enabledTab" end
        -- the rule's row in the list that is open. Xaya 2026-11-04: "deleting a condition / a cue forces you out of the rule you're
        -- editing entirely". This used the Smart Categories path even in the Enabled list; SelectKeep turned it into a path through
        -- the type row ("loaded / smart_icon / rule5"), which does not exist there, so the pane fell back to another page.
        local newPath
        if sub == "smartTab" then
            newPath = { RulePath(rule) }
            local cat = type(oldSel) == "string" and oldSel:match("^all\001smart\001(smart_[%w_]+)\001")
            if cat and ns.SmartMatch(rule, cat) then   -- still has the type it was picked under: stay on that row
                for i, r in ipairs(ns.rules) do
                    if r == rule then newPath = { "cooldowns", "smartTab", "all", "smart", cat, "rule" .. i }; break end
                end
            end
        else
            local okc, ctx = pcall(ns.ReadContext)
            newPath = { ns.ScopePath(rule, okc and ctx or nil) }
        end
        if newPath[2] == sub and oldSel == table.concat(newPath, "\001", 3) then return end   -- the row did not move: nothing to do
        -- the row moved (its index after a delete, or the type row it was selected through): follow it, and keep the same tab open.
        -- The rule's own tab status lives at its full path (cooldowns / <sub-tab> / ...).
        local tab
        if type(oldSel) == "string" then
            local segs = { "cooldowns", sub }
            for seg in oldSel:gmatch("[^\001]+") do segs[#segs + 1] = seg end
            local st = AceConfigDialog:GetStatusTable(APP, segs)
            tab = st and st.groups and st.groups.selected
        end
        ns.SelectKeep(unpack(newPath))
        if tab then
            local st2 = AceConfigDialog:GetStatusTable(APP, newPath)
            if st2 then st2.groups = st2.groups or {}; st2.groups.selected = tab end
        end
    end)
end

-- for the other files of this folder (ns.OptionsApi.RuleEditorParts)
P.FolderById, P.FolderChain, P.FolderPath, P.FolderRules, P.FolderTopRules, P.FolderValues = FolderById, FolderChain, FolderPath, FolderRules, FolderTopRules, FolderValues
P.IsInFolder, P.RulePath, P.FolderRuleCounts = IsInFolder, RulePath, FolderRuleCounts
