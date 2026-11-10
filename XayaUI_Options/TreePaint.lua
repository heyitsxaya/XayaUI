-------------------------------------------------------------------------------
-- TreePaint.lua : the settings window's tree rows (every tab's left pane) and its widget walker, ns.DecorateTrees: row text and
-- selection look, banners, the open / close arrow, a feature's tick box on its row (Tree.RowSwitch), the name's insets, the
-- left-aligned headings, and the decorate pass Skin.lua layers its look on.
-- (Options 0.6.87, platform split P4b; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7 and Q1) Moved unchanged out of the rule
-- editor's Sidebar.lua and SpellSearch.lua when the rule editor was split off (it is now XayaUI_Rules/Editor/): these
-- painted every tab's rows, the feature tabs' tick boxes included, so they belong to the window (Platform), not to XayaUI Rules.
-- What only the rules tree has is the rule editor's, registered here as ns.OptionsApi.TreePaint.rules when it loads (nil while
-- XayaUI Rules is off, and then none of its files is read):
--   RowKind(uv, lastKey) -> isRoot, isSub, upper   BannerTint(uv) -> colour or nil   Spacer(button) -> bool
--   Begin(button) -> vis, snd, rawObjs, inSC, hasIcons, isRootRow, gone   Hooks(button)   Reorder(button, level, x0) -> x0
--   RowToggle(button, x0) -> cfg or nil   Icons(button, vis, snd, hasIcons)   Note(button, inSC) -> text or nil
--   Side(button, rawObjs, vis)   Widget(w) (an Icon or EditBox widget: spell tooltips and search boxes)
-- Loaded after Options.lua (ns.OptionsApi.Shared) and before Skin.lua (which wraps ns.DecorateTrees at its own load).
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local APP, AceConfigDialog, Tree = O.APP, O.AceConfigDialog, O.Tree
ns.OptionsApi.TreePaint = ns.OptionsApi.TreePaint or {}
local TP = ns.OptionsApi.TreePaint

-- (review R13) AceGUI keeps one pool of widgets for every addon, so a tree or edit box XayaUI's window used can next be another
-- addon's. AceConfigDialog writes the app's name into each control it makes and AceGUI wipes it on release: a widget is XayaUI's
-- only while it says APP. Every hook XayaUI leaves on a pooled widget (they cannot be taken off) checks this first.
function TP.Ours(w)
    local u = type(w) == "table" and w.userdata
    return (type(u) == "table" and u.appName == APP) and true or false
end

local function MakeChevron(button)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(16, 16)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b:SetScript("OnClick", function(self)
        local tree = button.obj
        local st = tree and (tree.status or tree.localstatus)
        local uv = button.uniquevalue
        if st and st.groups and uv then
            st.groups[uv] = not st.groups[uv]
            tree:RefreshTree()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Expand / collapse the list under this row")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Sidebar highlight: every category / folder row is neutral gray; the selected row, its parent groups and the rows inside the
-- selected group take the purple of the Advanced Cue Tracking banner. (Row sizes and fonts still follow BannerTint.)
ns.NEUTRAL_TINT = { 0.2, 0.2, 0.24 }
function ns.SelectedUV(button)
    local tree = button and button.obj
    local st = tree and (tree.status or tree.localstatus)
    return st and st.selected and tostring(st.selected) or nil
end

-- Row text and selection look (2026-10-31 UI pass). One deterministic style per tier, re-applied on every pass, so rows can no
-- longer drift apart: AceGUI swaps the button's font object (gold normal / white highlight) on select and hover, and the old
-- code captured whichever one it saw first. Tiers: root headers (outlined), top-level categories, sub-categories, rules.
-- Capitals only on ALL RULES, LOADED, NOT LOADED and SMART CATEGORIES.
do
local TREE_TXT = { 0.96, 0.96, 0.98 }     -- unselected rows
local TREE_SEL = { 0.78, 0.62, 1.0 }      -- selected row, "alternate text color" style
ns.TREE_GRAD = { 0.30, 0.08, 0.45 }       -- parent-group gradient: dark purple (left) to black (right)
ns.TREE_BAR = { 0.34, 0.34, 0.40 }
do local TH = ns.Theme   -- style sheet: these tables are filled in place whenever the theme changes
   -- (Options 0.6.104, #472) bound to the settings window's theme scope ("settings"): its own colours, else the global theme as before
   if TH then TH.Bind("text", TREE_TXT, "settings"); TH.Bind("accentText", TREE_SEL, "settings"); TH.Bind("gradStart", ns.TREE_GRAD, "settings"); TH.Bind("treeBar", ns.TREE_BAR, "settings") end end        -- every folder-tree bar (banner edge bar and guide bars) shares this muted color

local function RowTier(button)
    local uv = button.uniquevalue and tostring(button.uniquevalue) or ""
    local lastKey = uv:match("([^\001]+)$") or ""
    -- (P4b) which tier a row is (a root header, a group's sub-category, a top-level category) only the rules tree knows: its rows ask
    -- the rule editor (TP.rules.RowKind / BannerTint, XayaUI_Rules/Editor/Sidebar.lua); every other row is a plain row
    local R = TP.rules
    local isRoot, isSub, upper = false, false, false
    if R then isRoot, isSub, upper = R.RowKind(uv, lastKey) end
    local isCue = (not isRoot) and (not isSub) and (R and R.BannerTint(uv)) ~= nil
    local base = select(2, GameFontNormal:GetFont()) or 12
    local catSize = math.floor(base * 1.15 * 1.2 * 0.85 * 10 + 0.5) / 10
    local subSize = math.floor(base * 1.2 * 0.85 * 10 + 0.5) / 10
    local size, flags = base, ""
    if isRoot then size = math.floor(catSize * 1.15 * 10 + 0.5) / 10; flags = "OUTLINE"
    elseif isCue then size = catSize
    elseif isSub then size = subSize end
    return { uv = uv, isRoot = isRoot, isCue = isCue, isSub = isSub, upper = upper, catSize = catSize, subSize = subSize, size = size, flags = flags }
end

function ns.PaintRowText(button)
    local fs = button.text
    if not (fs and fs.SetFont) then return end
    local t = RowTier(button)
    do
        local TH = ns.Theme
        local fp = TH and TH.FontPath()
        if fp and pcall(fs.SetFont, fs, fp, TH.Size(t.size), t.flags) then else fs:SetFont((GameFontNormal:GetFont()), TH and TH.Size(t.size) or t.size, t.flags) end
    end
    local sel = ns.SelectedUV(button)
    local col = (sel ~= nil and sel == t.uv and ns.SelStyle() == "text") and TREE_SEL or TREE_TXT
    fs:SetTextColor(col[1], col[2], col[3], 1)
    fs:SetAlpha(1)
    if t.isRoot and t.upper then
        local text = fs:GetText() or ""
        local up = text:upper()
        if up ~= text then fs:SetText(up) end
    end
    return t
end

-- hover swaps the button's font object (and with it the color) outside our passes: repaint right after
function ns.HookRowHover(button)
    if button.xuiTxtHook then return end
    button.xuiTxtHook = true
    local function again(self)
        if not (self.xuiFontDone and TP.Ours(self.obj)) then return end   -- (review R13) only while the row is in XayaUI's window
        ns.PaintRowText(self)
        C_Timer.After(0, function() if self.xuiFontDone and TP.Ours(self.obj) then ns.PaintRowText(self) end end)
    end
    button:HookScript("OnEnter", again)
    button:HookScript("OnLeave", again)
end
end   -- do (row text helpers)

local function PaintBanner(button)
    local R = TP.rules
    local c = R and R.BannerTint(button.uniquevalue)
    local t = ns.PaintRowText(button)
    if t then
        button.xuiFontDone = true
        ns.HookRowHover(button)
        if not button.xuiH0 then button.xuiH0 = button:GetHeight() end
        local want = button.xuiH0
        if t.isRoot then want = math.max(button.xuiH0, math.floor(t.catSize * 1.15 + 8))
        elseif t.isCue then want = math.max(button.xuiH0, math.floor(t.catSize + 8))
        elseif t.isSub then want = math.max(button.xuiH0, math.floor(t.subSize + 8)) end
        if math.abs(button:GetHeight() - want) > 0.5 then button:SetHeight(want) end
        for _, seg in ipairs(button.xuiSC and button.xuiSC.segs or {}) do seg:Hide() end
    end
    -- selected row, "highlighted bar" style: purple fading to black toward the right. Never on mouse-over.
    do
        local su = ns.SelectedUV(button)
        local mine = su ~= nil and su == (button.uniquevalue and tostring(button.uniquevalue) or "")
        if mine and ns.SelStyle() == "bar" then
            if not button.xuiSelTex then
                button.xuiSelTex = button:CreateTexture(nil, "BACKGROUND", nil, 0)
                button.xuiSelTex:SetAllPoints()
            end
            local st = button.xuiSelTex
            st:SetColorTexture(0.75, 0.25, 1, 0.6)
            pcall(st.SetGradient, st, "HORIZONTAL", CreateColor(0.75, 0.25, 1, 0.6), CreateColor(0, 0, 0, 0.15))
            st:Show()
        elseif button.xuiSelTex then
            button.xuiSelTex:Hide()
        end
    end
    -- blank divider row between All Rules and the Loaded / Not Loaded filters: a thin line, no text (the rules tree's rows; TP.rules.Spacer)
    local isSpacer = (R and R.Spacer(button)) and true or false
    if isSpacer then
        if not button.xuiDivider then
            button.xuiDivider = button:CreateTexture(nil, "ARTWORK")
            button.xuiDivider:SetHeight(1)
            button.xuiDivider:SetColorTexture(0.6, 0.6, 0.65, 0.45)
        end
        button.xuiDivider:ClearAllPoints()
        button.xuiDivider:SetPoint("LEFT", button, "LEFT", 6, 0)
        button.xuiDivider:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        button.xuiDivider:Show()
    elseif button.xuiDivider then
        button.xuiDivider:Hide()
    end
    -- parent-group gradient: when the selection is nested (root > group > ... > item), only the TOPMOST group of the chain
    -- (the row right under the root) gets a dark purple to black left-to-right gradient. Settings > Display Options turns it off.
    local uvStr = button.uniquevalue and tostring(button.uniquevalue) or ""
    local selUV = ns.SelectedUV(button)
    local nestTop = false
    if selUV and ns.ParentGradientOn() then
        local s1, s2, s3 = selUV:match("^([^\001]+)\001([^\001]+)\001([^\001]+)")
        if s3 and uvStr == (s1 .. "\001" .. s2) then nestTop = true end
    end
    if not c and not nestTop then
        if button.xuiBanner then button.xuiBanner:Hide(); button.xuiBannerBar:Hide() end
        return
    end
    if not button.xuiBanner then
        button.xuiBanner = button:CreateTexture(nil, "BACKGROUND", nil, -2)
        button.xuiBanner:SetAllPoints()
        button.xuiBannerBar = button:CreateTexture(nil, "BACKGROUND", nil, -1)
        button.xuiBannerBar:SetPoint("TOPLEFT"); button.xuiBannerBar:SetPoint("BOTTOMLEFT"); button.xuiBannerBar:SetWidth(6)
    end
    local b, bar = button.xuiBanner, button.xuiBannerBar
    if nestTop then
        local g = ns.TREE_GRAD
        b:SetColorTexture(g[1], g[2], g[3], 0.95)
        pcall(b.SetGradient, b, "HORIZONTAL", CreateColor(g[1], g[2], g[3], 0.95), CreateColor(0, 0, 0, 0.95))
    else
        local col = ns.NEUTRAL_TINT   -- selection is drawn by xuiSelTex / the text color, not by this banner
        local ba = 0.45
        b:SetColorTexture(col[1], col[2], col[3], 0.5 * ba)
        pcall(b.SetGradient, b, "HORIZONTAL", CreateColor(col[1], col[2], col[3], 0.85 * ba), CreateColor(col[1], col[2], col[3], 0.2 * ba))
    end
    bar:Hide()   -- the old edge bar clipped outside the sidebar; folder-tree bars are drawn under the +/- toggles (PaintGuides)
    b:Show()
end

-- The rule list's right-hand columns, from the row's right edge (Options 0.6.64; REQUEST-LOG UI-70: "icons still not appropriately
-- handled and display irregularly"; UI-72, her answer "copy the WA format w/ toggle being under group as previously suggested"): every
-- row keeps the same slots, left to right [lock][note][preview][open / close], each empty where the row has nothing of that kind, so
-- the icons line up; a header's open / close button is the far-right one with the preview just left of it (WeakAuras); a group's
-- sits under its icon. Two-row rows (a rule with its type icon) keep their own: the preview on the top row, the locks under it.
ns.OptionsApi.SIDE_COL = { expand = 4, preview = 4 + 19, note = 4 + 19 * 2, lock = 4 + 19 * 3 }

-- Sidebar switches (Options 0.6.40; Xaya, 2026-11-05: "move all enable/disable toggles onto the sidebar instead for all bonus
-- features and QoL items"). A feature page, or one of its parts (a node under it in the left pane), that has one on / off carries
-- it as group.xuiSwitch: an ordinary AceConfig toggle (name, desc, get, set; hidden / disabled optional) that is NOT in its args, so
-- the page no longer shows it. Its row in a feature tab's left pane gets a tick box left of its name (placement below) that shows
-- get() and calls set() (the same function the in-page switch called, so every side effect stays). get / set receive the info table AceConfigDialog
-- would give a toggle at that place (path, then "xuiSwitch"). The box's tooltip is the switch's name and desc. A click on the box
-- is the box's own: it never selects or opens the row (the game hands a click to the topmost mouse-enabled frame under the cursor,
-- and the box sits above the row; INFERENCE, standard behaviour the rule rows' eye / lock buttons rely on too, not stated in the
-- API documentation). Rows whose page has no single on / off (Utilities, Cursor) get no box.
-- Where the box sits (#369: a row's name room is precious): every row keeps a 16 px slot left of its name for the open / close
-- arrow, empty on a row without parts; the box takes that slot, so it costs those names nothing. On a row that has parts (Character
-- Toolkit) the box sits right after the arrow slot and only that row's name moves right by the box's width; it stays there while
-- the parts are hidden too, so the box never moves under the mouse when it is clicked.
-- Only rows of the feature tabs are looked at (the Rules trees skip at once: the window repaints every row 4 times a second).
Tree.SWITCH_W, Tree.SWITCH_GAP = ns.Style.switch.size, 1   -- box size (the arrow slot's width); space after the arrow on a row that has one
function Tree.RowSwitch(button)
    local tree = button and button.obj
    local user = tree and tree.GetUserDataTable and tree:GetUserDataTable()
    local path = user and user.path
    if type(path) ~= "table" or not ns.OptionsApi.TABS[path[1] or ""] or #path ~= 1 then return nil end
    local g = user.option
    for seg in tostring(button.uniquevalue or ""):gmatch("[^\001]+") do
        g = type(g) == "table" and type(g.args) == "table" and g.args[seg] or nil
    end
    local sw = type(g) == "table" and g.xuiSwitch or nil
    if type(sw) ~= "table" or type(sw.get) ~= "function" or type(sw.set) ~= "function" then return nil end
    local info = { path[1] }
    for seg in tostring(button.uniquevalue):gmatch("[^\001]+") do info[#info + 1] = seg end
    info[#info + 1] = "xuiSwitch"
    info.options, info.option, info.appName, info.type, info.uiType, info.uiName = user.options, sw, APP, "toggle", "dialog", "AceConfigDialog-3.0"
    local hid = sw.hidden
    if type(hid) == "function" then local ok, h = pcall(hid, info); hid = ok and h end
    if hid then return nil end
    -- parts: the node lists parts under it in the left pane (so it has the open / close arrow), even while they are hidden (the
    -- Character Toolkit hides its parts while it is off): the box keeps one place whether the arrow shows or not
    local parts = false
    if (g.childGroups or "tree") == "tree" then
        for _, c in pairs(type(g.args) == "table" and g.args or {}) do
            if type(c) == "table" and c.type == "group" and not c.inline then parts = true; break end
        end
    end
    return sw, info, parts, g
end
-- A click on a row's tick box: the switch's own set, then exactly one redraw. That redraw reuses the tree drawn last (Tree.Keep):
-- a switch's state is read only by functions inside the tree (get / hidden / disabled / name), never while the tree is built, so a
-- fresh build would give the same tree; tests/sidebar_switches_run.py builds the whole tree with every switch off and on and
-- compares the two. The redraws the set asks for (Notify, CONFIG_CHANGED) are dropped while it runs (Tree.hold, see Notify), and a
-- console "view" redraw waiting for the next frame (Tree.ViewChanged) is cancelled: this redraw shows that change too.
function Tree.SwitchClick(box)
    local sw, info = Tree.RowSwitch(box:GetParent())
    if not sw then return end
    Tree.hold = true
    local ok, err = pcall(sw.set, info, box:GetChecked() and true or false)
    Tree.hold = nil
    if not ok then local h = geterrorhandler and geterrorhandler(); if h then h(err) end end
    local of = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    if not (of and of.frame and of.frame:IsShown()) or Tree.AcePending() then return end   -- closed, or a fresh redraw already on its way
    local user = of:GetUserDataTable()
    Tree.view = nil
    Tree.Keep()
    pcall(AceConfigDialog.Open, AceConfigDialog, APP, unpack(user.basepath or {}))
    Tree.keep = nil
end
-- Hover on a row's tick box (Options 0.6.63; REQUEST-LOG UI-42; Xaya 2026-11-06: "hovering over this should not show "off" by default.
-- all should just show a one-sentence description and an enabled/disabled status"): the feature's name (its row's), one sentence
-- (the switch's tip; without one, the first sentence of its desc), and Enabled / Disabled. Never an "Off: ..." text.
function Tree.OneSentence(sw, info)
    local function val(v) if type(v) == "function" then local ok, r = pcall(v, info); return ok and r or nil end return v end
    local t = val(sw.tip)
    if type(t) ~= "string" or t == "" then
        local d = val(sw.desc)
        t = type(d) == "string" and (d:match("^(.-[%.!?])%s") or d) or ""
        if t:match("^Off[:%s]") then t = "" end
    end
    return t
end
ns.OptionsApi.SwitchSentence = Tree.OneSentence
function Tree.SwitchTip(box)
    local sw, info, _, g = Tree.RowSwitch(box:GetParent())
    if not sw then return end
    local function val(v) if type(v) == "function" then local ok, r = pcall(v, info); return ok and r or nil end return v end
    local on = false
    if type(sw.get) == "function" then local ok, v = pcall(sw.get, info); on = ok and v and true or false end
    GameTooltip:SetOwner(box, "ANCHOR_RIGHT")
    GameTooltip:SetText(tostring(val(g and g.name) or val(sw.name) or ""))
    local t = Tree.OneSentence(sw, info)
    if t ~= "" then GameTooltip:AddLine(t, 1, 1, 1, true) end
    -- the status in theme colours (UI-49): Enabled in the theme's body text, Disabled in its muted text
    local c = on and ((ns.Theme and ns.Theme.Col) and ns.Theme.Col("xui-text", "text", "settings", { 1, 1, 1, 1 }) or { 1, 1, 1, 1 }) or ns.OptionsApi.Muted()
    GameTooltip:AddLine(on and "Enabled" or "Disabled", c[1], c[2], c[3])
    GameTooltip:Show()
end
-- Called by DecorateButton for every row (toggleCfg: the row already has a ROW_TOGGLES box; x0: where the row's arrow slot starts;
-- arrow: the row shows its open / close arrow in that slot). Returns how far the name must move right for the box (0 when the box
-- sits in the empty arrow slot).
function ns.OptionsApi.PaintRowSwitch(button, toggleCfg, x0, arrow)
    local sw, info, parts
    if not toggleCfg then sw, info, parts = Tree.RowSwitch(button) end
    arrow = arrow or parts
    local box = button.xuiSwitchBox
    if not sw then if box then box:Hide() end return 0 end
    if not box then
        box = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
        box:SetSize(Tree.SWITCH_W, Tree.SWITCH_W)
        box:EnableMouse(true)   -- (a button takes the mouse anyway; stated, since the box must take the click instead of the row)
        box:SetScript("OnClick", Tree.SwitchClick)
        box:SetScript("OnEnter", Tree.SwitchTip)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button.xuiSwitchBox = box
    end
    box:SetFrameLevel(button:GetFrameLevel() + 3)
    local ok, on = pcall(sw.get, info)
    box:SetChecked((ok and on) and true or false)
    local dis = sw.disabled
    if type(dis) == "function" then local okD, d = pcall(dis, info); dis = okD and d end
    box:SetEnabled(not dis)
    box:ClearAllPoints()
    local x, shift = x0 or 6, 0
    if arrow then x = x + Tree.SWITCH_W + Tree.SWITCH_GAP; shift = Tree.SWITCH_W + Tree.SWITCH_GAP end   -- (the arrow slot is SWITCH_W wide)
    box:SetPoint("LEFT", button, "LEFT", x, 0)
    box:Show()
    return shift
end

-- One tree row, every pass. The parts every tree has (text tier and selection look, banner, open / close arrow, a feature's tick box,
-- the name's insets) are painted here; what only the rules tree has (preview eye / headphone, multi-select wash, drag, reorder
-- arrows, rename, the QoL rows' tick boxes, the Smart Categories note, the locks) comes from the rule editor through TP.rules, in
-- the same order as before the split (P4b; the rule editor is XayaUI_Rules/Editor/ and is set up only while XayaUI Rules is on).
local function DecorateButton(button)
    local R = TP.rules
    button.xuiTextL, button.xuiTextR = nil, nil   -- #369: set again below for this row (a reused button never keeps another row's)
    do   -- the tree reuses its row buttons: when one now shows a different row, drop what the previous row left on it (height, note, type icons)
        local uvnow = tostring(button.uniquevalue or "")
        if button.xuiLastUV ~= uvnow then
            button.xuiLastUV = uvnow
            if button.xuiH0 and not button.xuiGone and (button:GetHeight() or 0) > button.xuiH0 + 0.5 then button:SetHeight(button.xuiH0) end
            button.xuiNoteH = nil
            for _, k in ipairs({ "xuiSub", "xuiType", "xuiType2" }) do if button[k] and button[k].Hide then button[k]:Hide() end end
        end
    end
    PaintBanner(button)
    -- the rules tree: guide bars, the multi-select wash, what the row previews (vis / snd), whether it is in Smart Categories, whether
    -- it carries preview icons, whether it is a root header; gone = a row drawn as nothing (TP.rules.Begin)
    local vis, snd, rawObjs, inSC, hasIcons, isRootRow
    if R then
        local gone
        vis, snd, rawObjs, inSC, hasIcons, isRootRow, gone = R.Begin(button)
        if gone then return end
    end
    if button.xuiGone then
        button.xuiGone = nil
        button:SetHeight(18); button:SetAlpha(1); button:EnableMouse(true)
    end
    if R then R.Hooks(button) end   -- right-click menus, drag, Ctrl / Shift+click, double-click rename (rules tree)
    local tree = button.obj
    local level = (button.level or 1) - (inSC and 2 or 0)
    if level < 1 then level = 1 end
    local canExpand = button.toggle and button.toggle:IsShown() and true or false
    if button.text then
        button.text:SetWordWrap(false)
        button.text:SetPoint("RIGHT", button, "RIGHT", -4, 2)
        button.xuiTextR = 4
    end
    -- Every row of a level uses the same fixed slots: [arrow 16][eye 17][headphone 17][text]. A row without an arrow or
    -- without icons keeps its (empty) slots, so the text of all rows on one level lines up. Blizzard's tiny +/- is hidden
    -- (still "shown", so canExpand stays readable) because our arrow replaces it on every expandable row.
    local CHEV_W = 16
    -- left gutter (4px wider than before). Root headers and first-level groups start at the same x (flush with the sidebar wall);
    -- each deeper level steps in by 8px as before.
    local x0 = (level <= 1) and 6 or (8 * level - 9)
    x0 = ns.OptionsApi.NestX(button, level, x0)   -- (Options 0.6.55) a feature tab's part: its parent's name + 8 px
    if R then x0 = R.Reorder(button, level, x0) end   -- the rules tree's up / down arrows; chevron and text sit right of them
    if button.toggle then
        button.toggle:SetAlpha(canExpand and 0 or 1)
        button.toggle:EnableMouse(not canExpand)
    end
    local tw = ns.PaintTypeIcon and ns.PaintTypeIcon(button, x0) or 0   -- icon at the left of the row (0 = none)
    button.xuiTwoRow = (tw > 0 and not (ns.CondensedOn and ns.CondensedOn())) and true or false
    local chevMode = "left"
    if canExpand then
        if not button.xuiChev then button.xuiChev = MakeChevron(button) end
        local st = tree and (tree.status or tree.localstatus)
        local expanded = st and st.groups and st.groups[button.uniquevalue]
        button.xuiChev:SetNormalTexture(expanded and 130821 or 130838)
        button.xuiChev:SetPushedTexture(expanded and 130820 or 130836)
        button.xuiChev:ClearAllPoints()
        if isRootRow then          -- root headers: round toggle at the right end
            chevMode = "right"
            button.xuiChev:SetSize(16, 16)
            -- (Options 0.6.64; UI-70 / UI-72, her answer "copy the WA format": a header's open / close button at the far right end, the
            -- preview just left of it; it sat 46 px in before, on top of the eye and headphone columns)
            button.xuiChev:SetPoint("RIGHT", button, "RIGHT", -ns.OptionsApi.SIDE_COL.expand, 0)
        elseif tw > 0 then         -- groups: toggle sits under the group's icon
            chevMode = "icon"
            button.xuiChev:SetSize(14, 14)
            button.xuiChev:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", x0 - 2, 0)
        else
            button.xuiChev:SetSize(16, 16)
            button.xuiChev:SetPoint("LEFT", button, "LEFT", x0, 0)
        end
        button.xuiChev:SetFrameLevel(button:GetFrameLevel() + 4)
        button.xuiChev:Show()
    elseif button.xuiChev then
        button.xuiChev:Hide()
    end
    -- QoL rows of the rules tree (Stat Tracking, Buff Bars): a left-aligned tick box is the on/off switch for the whole element
    local toggleCfg = R and R.RowToggle(button, x0) or nil
    button.xuiIconR = 0
    if R then R.Icons(button, vis, snd, hasIcons) end   -- the preview eye / headphone (sets button.xuiIconR)
    if chevMode == "right" then button.xuiIconR = math.max(button.xuiIconR or 0, ns.OptionsApi.SIDE_COL.expand + 16 + 3) end
    -- a feature's on / off as a tick box in the row's arrow slot, or right after the arrow (Options 0.6.40)
    local swShift = ns.OptionsApi.PaintRowSwitch(button, toggleCfg, x0, canExpand and chevMode == "left")
    do
        local iconSlots = toggleCfg and 26 or swShift   -- only an on / off tick box sits left of the label now
        local lead = (tw > 0) and tw or ((chevMode == "right") and 0 or CHEV_W)   -- icon column, or the left chevron slot
        -- (Options 0.6.63; UI-47 / UI-8: "Parent's name + 8 px") a feature tab's child row with no tick box and no open / close button
        -- keeps no empty slot: its name itself starts 8 px right of its parent's name (it started 27 px in: the empty 16 px slot + 3)
        if (button.level or 1) >= 2 and tw == 0 and not canExpand and not toggleCfg and swShift == 0
            and not (button.xuiSwitchBox and button.xuiSwitchBox:IsShown()) and ns.OptionsApi.FeatureRow(button) then
            lead = -3
        end
        if tw > 0 then
            local h = math.max(button:GetHeight() or 0, ns.TYPE_ICON_SIDEBAR_H + 6)
            if math.abs((button:GetHeight() or 0) - h) > 0.5 then button:SetHeight(h) end
        end
        -- Smart Categories: a small note under the rule's name says which of the regular groups it is in (TP.rules.Note)
        local note = R and R.Note(button, inSC) or nil
        if button.text then button.text:SetPoint("LEFT", button, "LEFT", x0 + lead + iconSlots + 3, note and 8 or 2) end
        button.xuiTextL = x0 + lead + iconSlots + 3   -- #369: the name's left inset (Skin.lua ns.EnsureNameRoom)
        ns.OptionsApi.NoteNameL(button)
        if note then
            if not button.xuiSub then
                button.xuiSub = button:CreateFontString(nil, "OVERLAY")
                button.xuiSub:SetFont((GameFontNormal:GetFont()), 10, "")
                button.xuiSub:SetJustifyH("LEFT"); button.xuiSub:SetWordWrap(false)
                button.xuiSub:SetTextColor(0.6, 0.6, 0.65)
            end
            local sf = button.xuiSub
            sf:SetText("in " .. note)
            sf:ClearAllPoints()
            sf:SetPoint("TOPLEFT", button.text, "BOTTOMLEFT", 0, -1)
            sf:SetPoint("RIGHT", button, "RIGHT", -((button.xuiIconR or 0) + 8), 0)
            sf:Show()
            if (button:GetHeight() or 0) < 30 then button:SetHeight(30); button.xuiNoteH = true end
        else
            if button.xuiSub then button.xuiSub:Hide() end
            if button.xuiNoteH and tw == 0 then button:SetHeight(18) end
            button.xuiNoteH = nil
        end
    end
    if R then R.Side(button, rawObjs, vis) end   -- right side: movement lock + edit lock (rule, folder and all-rules rows only)
end

-- A decoration error must never abort AceGUI's tree layout (that blanks the whole window). Errors are kept, printed once per kind.
function ns.SafeDecorate(b)
    local ok, err = pcall(DecorateButton, b)
    if ok then ok, err = pcall(ns.OptionsApi.GreyRow, b) end   -- (Options 0.6.55) after every colour the row gets
    if not ok then
        ns.lastTreeErr = tostring(err)
        if not ns.treeErrShown or ns.treeErrShown ~= ns.lastTreeErr then
            ns.treeErrShown = ns.lastTreeErr
            ns.Print("sidebar decoration error (please report): " .. ns.lastTreeErr)
        end
    end
end

-- (Options 0.6.106; request log row 20, Xaya 2026-11-08: "deleting auras shifts the rule sidebar up still") A delete in the Rules
-- sidebar goes back to the list's top row and leaves the scroll position it had on the tree's status table (xuiKeepScroll;
-- XayaUI_Rules/Editor/TreeHelpers.lua ns.GoHomeKeepScroll). The window rebuild re-selects that row through AceGUI's TreeGroup:Select,
-- which scrolls it into view (or leaves scrollToSelection on the status table for the tree's first drawn frame). Once the rebuild is
-- done (the Open wrapper in Options.lua), the kept position goes back and the scroll-to-selection is dropped. AceGUI's RefreshTree
-- clamps it, so a list now shorter than the view stays at its bottom. Only after a rebuild: a decorate pass before it would see the old
-- tree and spend the mark too early.
local afterRebuild = false
local function KeepScroll(tree)
    local st = tree.status or tree.localstatus
    local keep = st and st.xuiKeepScroll
    if keep == nil then return end
    st.xuiKeepScroll = nil
    st.scrollToSelection = nil
    st.scrollvalue = keep
    tree:RefreshTree()
end

-- (review R13) The tree went to another addon (AceGUI's pool): its rows go back to how AceGUI draws them, once, before that owner's
-- first redraw. XayaUI's parts on a row are kept on keys that start with "xui"; the rules tree's own part is TP.rules.Release.
local function ReturnRows(tree)
    tree.xuiPainted = nil
    for _, b in ipairs(tree.buttons or {}) do
        for k, v in pairs(b) do
            if type(k) == "string" and k:sub(1, 3) == "xui" and type(v) == "table" and type(v.Hide) == "function" then v:Hide() end
        end
        for _, g in ipairs(b.xuiGuides or {}) do g:Hide() end
        b:SetHeight(b.xuiH0 or 18); b:SetAlpha(1); b:EnableMouse(true)
        if b.toggle then b.toggle:SetAlpha(1); b.toggle:EnableMouse(true) end
        if b.text and b.text.SetFontObject then b.text:SetFontObject(b:GetNormalFontObject() or GameFontNormal) end   -- (PaintRowText set its own font)
        b.xuiGone, b.xuiLastUV, b.xuiNoteH, b.xuiFontDone, b.xuiTextL, b.xuiTextR = nil, nil, nil, nil, nil, nil
    end
    if TP.rules and TP.rules.Release then pcall(TP.rules.Release, tree) end
end
-- (A23 SD-12) Every tree XayaUI painted goes back at once when the window closes (Options.lua Tree.Closed), so that while it is closed
-- the RefreshTree wrapper below finds nothing to put back and only passes through. (A tree handed on while the window is open is put
-- back at its new owner's first redraw, as before.)
local painted = setmetatable({}, { __mode = "k" })
function TP.ReturnAll()
    for tree in pairs(painted) do
        if not TP.Ours(tree) then painted[tree] = nil; if tree.xuiPainted then pcall(ReturnRows, tree) end end
    end
end

local function DecorateTree(tree)
    if afterRebuild then pcall(KeepScroll, tree) end
    if not tree.xuiHooked then
        tree.xuiHooked = true
        local orig = tree.RefreshTree
        -- (review R13) The wrapper stays on the widget (AceGUI hands the same tree back to XayaUI's next pane, which must paint at
        -- once), but it paints only while the tree is XayaUI's; another addon's tree gets AceGUI's RefreshTree and its rows back.
        tree.RefreshTree = function(self, ...)
            if not TP.Ours(self) then if self.xuiPainted then pcall(ReturnRows, self) end return orig(self, ...) end
            self.xuiPainted = true; painted[self] = true
            orig(self, ...)
            ns.OptionsApi.WithCueMemo(function()   -- (Options 0.6.69) one cue lookup pass for all the visible rows
                for _, b in ipairs(self.buttons or {}) do if b:IsShown() then ns.SafeDecorate(b) end end
            end)
            if ns.EnsureNameRoom then pcall(ns.EnsureNameRoom, self) end   -- #369: room for every visible name
        end
        local status = tree.status or tree.localstatus
        if status and not status.xuiWide then
            status.xuiWide = true
            if (status.treewidth or 0) <= 175 then pcall(tree.SetTreeWidth, tree, 270, true) end
        end
    end
    tree.xuiPainted = true
    painted[tree] = true
    for _, b in ipairs(tree.buttons or {}) do
        if b:IsShown() then ns.SafeDecorate(b)
        else
            if b.xuiEye then b.xuiEye:Hide(); b.xuiHead:Hide() end
            if b.xuiEdit then b.xuiEdit:Hide() end
            if b.xuiUp then b.xuiUp:Hide(); b.xuiDown:Hide() end
            if b.xuiMove then b.xuiMove:Hide() end
            if b.xuiBanner then b.xuiBanner:Hide(); b.xuiBannerBar:Hide() end
            if b.xuiSelTex then b.xuiSelTex:Hide() end
            if b.xuiDivider then b.xuiDivider:Hide() end
            if b.xuiSwitchBox then b.xuiSwitchBox:Hide() end
        end
    end
end


-- Left-aligned section headers: AceGUI centers Heading text between two lines and Button text. Only widgets inside XayaUI's
-- own window are touched, and everything is put back when the widget is released (AceGUI recycles widgets across addons).
function ns.LeftRestore(w)
    if w.type == "Heading" and w.label then
        w.label:ClearAllPoints(); w.label:SetPoint("TOP"); w.label:SetPoint("BOTTOM"); w.label:SetJustifyH("CENTER")
        w.left:Show()
        w.left:ClearAllPoints(); w.left:SetPoint("LEFT", 3, 0); w.left:SetPoint("RIGHT", w.label, "LEFT", -5, 0)
        w.right:ClearAllPoints(); w.right:SetPoint("RIGHT", -3, 0); w.right:SetPoint("LEFT", w.label, "RIGHT", 5, 0)
        if w.frame and w.frame.xuiInfoIcon then w.frame.xuiInfoIcon:Hide() end
    elseif w.type == "Button" and w.text then
        w.text:SetJustifyH("CENTER")
    end
    w.xuiLeftOn = nil
end
function ns.HookRelease(w)
    if w.xuiRelHook then return end
    w.xuiRelHook = true
    local orig = w.OnRelease
    w.OnRelease = function(self, ...)
        if not self.xuiLeftOn then if orig then return orig(self, ...) end return end   -- (A23 SD-12) not XayaUI's now: AceGUI's own release
        ns.LeftRestore(self)
        if orig then return orig(self, ...) end
    end
end
function ns.LeftAlign(w)
    if w.type == "Heading" and w.label and w.left and w.right then
        local t = w.label:GetText()
        if not t or t == "" then return end
        if w.xuiLeftOn and not w.right:IsShown() then w.xuiLeftOn = nil end   -- re-acquired with new text: lay it out again
        if w.xuiLeftOn then return end
        ns.HookRelease(w)
        w.xuiLeftOn = true
        local hoptC = w.GetUserData and w:GetUserData("option")
        w.label:ClearAllPoints()
        local lx = (hoptC and type(hoptC.arg) == "table" and hoptC.arg.xuiCollapse) and 24 or 4   -- room for the open / close button (Skin.lua)
        w.label:SetPoint("TOPLEFT", w.frame, "TOPLEFT", lx, 0); w.label:SetPoint("BOTTOMLEFT", w.frame, "BOTTOMLEFT", lx, 0)
        w.label:SetJustifyH("LEFT")
        w.left:Hide()
        w.right:ClearAllPoints()
        w.right:SetPoint("RIGHT", w.frame, "RIGHT", -3, 0); w.right:SetPoint("LEFT", w.label, "RIGHT", 8, 0)
        w.right:Show()
        local hopt = w.GetUserData and w:GetUserData("option")
        if hopt and hopt.xuiInfo and ns.GetInfoIcon then   -- (i) next to the heading: hover for the explanation, click to pin it
            local ic = ns.GetInfoIcon(w.frame)
            ic.xuiText = hopt.xuiInfo; ic.xuiTitle = t
            ic:ClearAllPoints(); ic:SetPoint("LEFT", w.label, "RIGHT", 6, 0); ic:Show()
            w.right:ClearAllPoints()
            w.right:SetPoint("RIGHT", w.frame, "RIGHT", -3, 0); w.right:SetPoint("LEFT", ic, "RIGHT", 8, 0)
        elseif w.frame.xuiInfoIcon then
            w.frame.xuiInfoIcon:Hide()
        end
    elseif w.type == "Button" and w.text then
        local opt = w.GetUserData and w:GetUserData("option")
        if opt and type(opt.arg) == "table" and opt.arg.xuiLeft then
            if not w.xuiLeftOn then ns.HookRelease(w); w.xuiLeftOn = true; w.text:SetJustifyH("LEFT") end
        elseif w.xuiLeftOn then
            ns.LeftRestore(w)
        end
    end
end

local function Walk(w, depth)
    if not w or depth > 14 then return end
    if w.type == "Heading" or w.type == "Button" then ns.LeftAlign(w) end
    if (w.type == "Icon" or w.type == "EditBox") and TP.rules then TP.rules.Widget(w) end   -- the rule editor's spell tooltips and search boxes
    if w.type == "TreeGroup" then DecorateTree(w) end
    for _, c in ipairs(w.children or {}) do Walk(c, depth + 1) end
end

function ns.DecorateTrees(root, rebuilt)   -- rebuilt: called right after a window rebuild (Options.lua, the Open wrapper)
    root = root or (AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP])
    afterRebuild = rebuilt and true or false
    if root then ns.OptionsApi.WithCueMemo(function() pcall(Walk, root, 0) end); pcall(ns.OptionsApi.PaintTabSwitches, root) end   -- (0.6.69) one rule lookup pass for every row
    afterRebuild = false
end
