-------------------------------------------------------------------------------
-- XayaUI_Rules_Options/Sidebar.lua : The Rules sidebar: preview toggles, drag and drop, reorder arrows, copy / paste of rule settings, right-click menus, row
-- the rules tree's part of the row painting (ns.OptionsApi.TreePaint.rules; every tab's rows are painted by XayaUI_Options/TreePaint.lua),
-- and the selected rule / group and the Del key.
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-- Since P4b (XayaUI_Rules_Options 0.6.77) this folder is its own load-on-demand addon: the settings window loads it when it opens
-- while XayaUI Rules is on (XayaUI_Options/Options.lua ns.OptionsApi.LoadRuleEditor); with XayaUI Rules off none of its files is read.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local CoreS, PlatS, QolS, APP, AceConfigDialog, Tree = O.CoreS, O.PlatS, O.QolS, O.APP, O.AceConfigDialog, O.Tree
local Notify = O.Notify
local P = ns.OptionsApi.RuleEditorParts
local FolderById, FolderChain, FolderPath, FolderRules, FolderTopRules, FolderValues = P.FolderById, P.FolderChain, P.FolderPath, P.FolderRules, P.FolderTopRules, P.FolderValues
local IsInFolder, RulePath, StartNewRule, tf = P.IsInFolder, P.RulePath, P.StartNewRule, P.tf


-------------------------------------------------------------------------------
-- Sidebar preview toggles: an eye (visual) and a headphone (sound) on tree rows.
-- Rows map to objects by their tree key: all / f<id> (folder) / rule<n>; allbars / bar<n>.
-- Preview is temporary: it never edits a rule, and it clears when the window closes.
-------------------------------------------------------------------------------
-- Our own icons (Xaya, 2026-11-06: "change the audio preview icon to JUST a headphone icon please", "instead of gold, do a slash through to
-- indicate it being off", "do the same with the eye so it's clearer and our own icon please"; her pick "Yes, slash and dimmed"): a plain
-- eye / headphone while the preview is on, the same with a slash while it is off (and dimmed as before). Drawn for XayaUI (Media\UI).
local UI_MEDIA = "Interface\\AddOns\\XayaUI\\Media\\UI\\"
ns.PREVIEW_ICONS = {
    visual = { on = UI_MEDIA .. "xui_eye.tga", off = UI_MEDIA .. "xui_eye_off.tga" },
    sound = { on = UI_MEDIA .. "xui_headphone.tga", off = UI_MEDIA .. "xui_headphone_off.tga" },
}
-- the picture a preview toggle shows: the plain icon while its preview is on (st 1) or partly on (st 0.5), the slashed one while off (st 0)
-- the movement lock / mover (Xaya, 2026-11-06: "change lock icon to be simpler and flatter"; "use the more common color choice for the
-- lock and use the less common color for the mover icon (also flatten)": a white lock, a gold four-way arrow; own drawings)
ns.LOCK_ICON, ns.MOVE_ICON = UI_MEDIA .. "xui_lock.tga", UI_MEDIA .. "xui_move.tga"
function ns.PreviewIcon(kind, st)
    local ic = ns.PREVIEW_ICONS[kind == "visual" and "visual" or "sound"]
    return (st == 0) and ic.off or ic.on
end
function ns.OptionsApi.IconReport()
    local I = ns.PREVIEW_ICONS
    ns.Print("eye icon: " .. I.visual.on .. " (off: " .. I.visual.off .. ") | headphone icon: " .. I.sound.on .. " (off: " .. I.sound.off .. ")")
end

-- Returns visualObjs, soundObjs for a tree row (either may be nil)
-- What the eye / headphone on a RULE row previews: the rule's own display or sound (older rules) plus every cue it owns. A rule that
-- has cues and no display of its own is left out itself (previewing it would force-show an empty texture); without this a rule whose
-- cues are set but that has no condition yet previewed nothing. A function field, not a local: this file is near Lua's 200-locals limit.
function ns.PreviewTargets(r)
    local l, cues = {}, {}
    if r.uid and not r.isCue and not r.parentUid and ns.CuesOf then cues = ns.CuesOf(r) end
    local ownVisual = r.visual and r.visual.enabled
    local ownSound = r.sound and r.sound.enabled
    if #cues == 0 or ownVisual or ownSound then l[#l + 1] = r end
    for _, c in ipairs(cues) do l[#l + 1] = c end
    return l
end

-- Group previews (all / folder / smart / loaded / not loaded) skip what is switched off: a disabled rule (or a cue of one) is only
-- previewed from the Disabled list or from its own row. Inside Loaded / Not Loaded a group previews only the rules in that list.
function ns.PvScope(uv) local k = uv and uv:match("^([^\001]+)"); if k == "loaded" or k == "notloaded" or k == "disabled" then return k end end
function ns.PvKeep(r, scope, ctx)
    local owner = (r.parentUid and ns.FindParentRule and ns.FindParentRule(r)) or r
    local sc = ns.RuleScope(owner, ctx)
    if scope then return sc == scope end
    return sc ~= "disabled"
end
-- expand = true: the list holds rules by folder / scope, so cues are taken from their PARENT rule (a cue's own folder field is only
-- copied when it is made and can be stale or empty), and a parent that has cues but no display of its own is left out itself.
function ns.PvFilter(list, uv, expand)
    local scope = ns.PvScope(uv)
    local okc, ctx = false, nil
    if scope and scope ~= "disabled" then okc, ctx = pcall(ns.ReadContext); if not okc then ctx = nil end end
    local o = {}
    for _, r in ipairs(list) do
        if expand then
            if not r.parentUid and ns.PvKeep(r, scope, ctx) then
                for _, t in ipairs(ns.PreviewTargets(r)) do o[#o + 1] = t end
            end
        elseif ns.PvKeep(r, scope, ctx) then o[#o + 1] = r end
    end
    return o
end

local function Resolve(uv)
    if not uv then return nil end
    local last = uv:match("([^\001]+)$") or uv
    if last == "all" then
        local l = {}
        for _, r in ipairs(ns.rules or {}) do l[#l + 1] = r end
        l = ns.PvFilter(l, uv, true)
        return l, l
    elseif last == "loaded" or last == "notloaded" then
        -- Xaya, 2026-11-06: "loaded does not have an eye icon next to it to preview every loaded + enabled rule; not loaded also has the
        -- same problem": the root's eye previews every rule in that list (PvFilter keeps the rules whose scope is that list: enabled and
        -- loaded / enabled and not loaded). The eye only: she asked for no headphone there.
        local l = {}
        for _, r in ipairs(ns.rules or {}) do l[#l + 1] = r end
        return ns.PvFilter(l, last, true), nil
    elseif last == "allbars" then
        local l = {}
        for _, b in ipairs(ns.bars or {}) do l[#l + 1] = b end
        return l, nil
    end
    local n = last:match("^rule(%d+)$")
    if n then local r = ns.rules and ns.rules[tonumber(n)]; if r then local l = ns.PreviewTargets(r); return l, l end return nil end
    n = last:match("^bar(%d+)$")
    if n then local b = ns.bars and ns.bars[tonumber(n)]; if b then return { b }, nil end return nil end
    if last:match("^f%d") then
        local fl = FolderRules(last)
        if ns.PvScope(uv) == "disabled" then
            -- the Disabled list shows a group with only the rules it directly holds, so its preview covers exactly those
            local direct = {}
            for _, r in ipairs(fl) do if r.folder == last then direct[#direct + 1] = r end end
            fl = direct
        end
        local l = ns.PvFilter(fl, uv, true)
        return l, l
    end
    if last == "smart" or last:match("^smart_") then
        local l = {}
        local scope = uv:match("^(loaded)\001") or uv:match("^(notloaded)\001") or uv:match("^(disabled)\001")
        local okx, ctx2 = false, nil
        if scope then okx, ctx2 = pcall(ns.ReadContext) end
        for _, r in ipairs(ns.rules or {}) do
            if (last == "smart" and ns.SmartAny(r)) or (last ~= "smart" and ns.SmartMatch(r, last)) then
                if not scope or (okx and ns.RuleScope(r, ctx2) == scope) then l[#l + 1] = r end
            end
        end
        l = ns.PvFilter(l, uv)
        return l, l
    end
    if last == "loaded" or last == "notloaded" or last == "disabled" then
        local l = {}
        local okc, ctx = pcall(ns.ReadContext)
        for _, r in ipairs(ns.rules or {}) do
            if ns.RuleScope(r, okc and ctx or nil) == last then l[#l + 1] = r end
        end
        l = ns.PvFilter(l, uv, true)
        return l, l
    end
end

local function GroupState(objs, kind)
    local on = 0
    for _, o in ipairs(objs) do if ns.IsPreview(o, kind) then on = on + 1 end end
    if on == 0 then return 0 elseif on == #objs then return 1 end
    return 0.5
end

local soundAllDlg
local function ConfirmAllSounds(count, cb)
    local ui = PlatS.ui
    if ui and ui.skipSoundAllPrompt then cb(); return end
    if not soundAllDlg then
        local f = CreateFrame("Frame", "XayaUISoundAllDialog", UIParent, "BackdropTemplate")
        f:SetSize(390, 170); f:SetPoint("CENTER"); f:SetFrameStrata("TOOLTIP"); f:EnableMouse(true)
        f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.text:SetPoint("TOP", 0, -24); f.text:SetWidth(340)
        f.check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.check:SetPoint("BOTTOMLEFT", 22, 52)
        f.checkLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.checkLabel:SetPoint("LEFT", f.check, "RIGHT", 2, 0)
        f.checkLabel:SetText("Don't ask me again")
        f.yes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.yes:SetSize(110, 24); f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -8, 20); f.yes:SetText(YES)
        f.no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.no:SetSize(110, 24); f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 20); f.no:SetText(NO)
        f.no:SetScript("OnClick", function() f:Hide() end)
        ns.FlatButton(f.yes, true); ns.FlatButton(f.no)
        f.yes:SetScript("OnClick", function()
            if f.check:GetChecked() and PlatS.ui then PlatS.ui.skipSoundAllPrompt = true end
            f:Hide()
            if f.cb then local c = f.cb; f.cb = nil; c() end
        end)
        tinsert(UISpecialFrames, "XayaUISoundAllDialog")
        soundAllDlg = f
    end
    soundAllDlg.cb = cb
    soundAllDlg.check:SetChecked(false)
    soundAllDlg.text:SetText("Play all " .. count .. " sounds at once? They will loop together until you switch the preview off.")
    soundAllDlg:Show()
end

local function MakeToggle(button, kind)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(15, 15)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.kind = kind
    b.tex:SetTexture(ns.PreviewIcon(kind, 0))
    b:SetScript("OnClick", function(self)
        local objs = self.objs
        if not objs or #objs == 0 then return end
        local on = GroupState(objs, self.kind) < 1
        local kindNow = self.kind
        local function go()
            ns.SetPreview(objs, kindNow, on)
            if ns.DecorateTrees then ns.DecorateTrees() end
            -- A full window refresh rebuilds the sidebar and throws its scroll position to the top, so the eye does not trigger one.
            -- Only the open rule's own pane ("PREVIEW ON" note) needs it, and then the scroll position is put back.
            local S = ns.RulesTreeStatus and ns.RulesTreeStatus()
            local rn = type(S and S.selected) == "string" and S.selected:match("rule(%d+)$")
            local open = rn and ns.rules and ns.rules[tonumber(rn)]
            local hit = false
            if open then for _, o in ipairs(objs) do if o == open or (o.parentUid and ns.FindParentRule and ns.FindParentRule(o) == open) then hit = true; break end end end
            if not hit then return end
            local tree = button.obj
            local st = tree and (tree.status or tree.localstatus)
            local sv = st and st.scrollvalue
            Notify()
            if st and sv then
                local function put() st.scrollvalue = sv; if tree.scrollbar and tree.scrollbar.SetValue then pcall(tree.scrollbar.SetValue, tree.scrollbar, sv) end end
                put(); if C_Timer then C_Timer.After(0, put) end
            end
        end
        if on and kindNow == "sound" and #objs > 1 then ConfirmAllSounds(#objs, go) else go() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local what = (self.kind == "visual") and "Preview the texture / bar" or "Loop the sound"
        GameTooltip:SetText(what .. " (temporary)")
        GameTooltip:AddLine("Applies to everything under this row. Ignores conditions; never changes the rule.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Drag a rule row or a folder row (not "All rules") to move it (#343, 0.6.4):
--   rule onto a rule row      -> placed just above / below that rule (top / bottom half of the row), joining its group
--   rule onto a group row     -> moved into that group (end of its rules); onto "All rules" -> top level
--   group onto a group row    -> top quarter: placed above it, bottom quarter: below it (same parent), middle: nested inside it
--   group onto a rule row     -> moved into that rule's group
-- A gold line shows where an above / below drop lands; the row lights up for "into". Dropping anywhere else does nothing.
-- Reordering only swaps rules among the list positions their group already uses (like the arrows), so no other row changes place.
local drag, dragFrame = {}, nil
local function LastKey(uv) return uv and uv:match("([^\001]+)$") end
local function RowUnderCursor(tree)
    for _, b in ipairs(tree and tree.buttons or {}) do
        if b:IsShown() and b:IsMouseOver() then return b end
    end
end
function drag.DragNested(r) return (r and r.parentUid and ns.FindParentRule and ns.FindParentRule(r)) and true or false end
function drag.DragRuleKey(r) return (r.folder and FolderById(r.folder)) and r.folder or false end
function drag.DragFolderKey(f) return (f.parent and FolderById(f.parent)) and f.parent or false end
-- where on row b the cursor is: "before" / "after" / "into"
function drag.DropZone(b, kind, isFolderRow)
    local _, y = GetCursorPosition()
    local sc = (b.GetEffectiveScale and b:GetEffectiveScale()) or 1
    local top, bot = b:GetTop(), b:GetBottom()
    if not (y and top and bot) or top <= bot then return isFolderRow and "into" or "after" end
    local frac = (top - y / sc) / (top - bot)   -- 0 at the top edge, 1 at the bottom edge
    if not isFolderRow then return frac < 0.5 and "before" or "after" end
    if kind ~= "folder" then return "into" end
    if frac < 0.25 then return "before" end
    if frac > 0.75 then
        local st = b.obj and (b.obj.status or b.obj.localstatus)
        if st and st.groups and st.groups[b.uniquevalue] then return "into" end   -- open group: "below" would land after its whole contents
        return "after"
    end
    return "into"
end
-- returns ok, target folder id (nil = top level), anchor (rule or folder to sit next to, or nil), where ("before" / "after" / "into")
local function DropTarget(b, kind, obj, zone)
    local last = LastKey(b and b.uniquevalue)
    if not last then return false end
    local scope = tostring(b.uniquevalue or ""):match("^([^\001]+)")
    if last == "all" then return true, nil, nil, "into" end
    if last:match("^f%d") then
        local f = FolderById(last)
        if not f then return false end
        if kind == "rule" then
            if ns.IsCategoryRoot(f) then return false end   -- same rule as Move to: rules do not go straight into a Smart Category
            return true, last, nil, "into"
        end
        if f == obj or IsInFolder(last, obj.id) then return false end  -- itself or its own subfolder
        if zone == "into" or scope == "disabled" then return true, last, nil, "into" end   -- the Disabled list is flat: no above / below
        local parent = drag.DragFolderKey(f) or nil
        if parent and IsInFolder(parent, obj.id) then return false end
        return true, parent, f, zone
    end
    local n = last:match("^rule(%d+)$")
    local r = n and ns.rules and ns.rules[tonumber(n)]
    if r then
        if drag.DragNested(r) then r = ns.FindParentRule(r) end   -- a cue / condition row stands for its rule
        local fid = (r.folder and FolderById(r.folder)) and r.folder or nil
        if kind == "folder" then
            if fid and IsInFolder(fid, obj.id) then return false end
            return true, fid, nil, "into"
        end
        if r == obj then return false end
        return true, fid, r, (zone == "before") and "before" or "after"
    end
    return false
end
-- put item at the place the drop asked for, inside list positions that hold its siblings (rules in ns.rules, groups in ns.folders)
function drag.Rotate(arr, slots, item, anchor, where)
    local order, at = {}, nil
    for _, i in ipairs(slots) do if arr[i] ~= item then order[#order + 1] = arr[i] end end
    for k, x in ipairs(order) do if x == anchor then at = (where == "before") and k or (k + 1) end end
    table.insert(order, at or (#order + 1), item)
    local moved = false
    for k, i in ipairs(slots) do if arr[i] ~= order[k] then moved = true end; arr[i] = order[k] end
    return moved
end
-- apply a drop; returns true when anything changed (also used by tests/drag_drop_run.py)
function ns.DragPlace(kind, obj, target, anchor, where)
    local changed = false
    if kind == "rule" then
        if obj.folder ~= target then
            obj.folder = target; changed = true
            if not anchor then   -- dropped on a group row: it goes to the end of that group, where it can be seen
                for _, r in ipairs(ns.rules) do if r ~= obj and not drag.DragNested(r) and drag.DragRuleKey(r) == drag.DragRuleKey(obj) then anchor = r end end
                where = "after"
            end
        end
        if anchor then
            local key, slots = drag.DragRuleKey(obj), {}
            for i, r in ipairs(ns.rules) do if not drag.DragNested(r) and drag.DragRuleKey(r) == key then slots[#slots + 1] = i end end
            if drag.Rotate(ns.rules, slots, obj, anchor, where) then changed = true end
        end
    else
        if anchor and ns.NormalizeFolderOrder then ns.NormalizeFolderOrder() end   -- folders keep list order from the first move on
        if obj.parent ~= target then
            obj.parent = target; changed = true
            if not anchor and PlatS.ui and PlatS.ui.folderOrdered then   -- nested into a group: last of its groups
                for _, f in ipairs(ns.folders) do if f ~= obj and drag.DragFolderKey(f) == drag.DragFolderKey(obj) then anchor = f end end
                where = "after"
            end
        end
        if anchor then
            local key, slots = drag.DragFolderKey(obj), {}
            for i, f in ipairs(ns.folders) do if drag.DragFolderKey(f) == key then slots[#slots + 1] = i end end
            if drag.Rotate(ns.folders, slots, obj, anchor, where) then changed = true end
        end
    end
    return changed
end
function drag.DropLine(b)
    if not b.xuiDropLine then
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetHeight(2); t:SetColorTexture(1, 0.82, 0, 1)
        b.xuiDropLine = t
    end
    return b.xuiDropLine
end
function drag.ClearMarks()
    if drag.hl then pcall(drag.hl.UnlockHighlight, drag.hl); drag.hl = nil end
    if drag.line then pcall(drag.line.Hide, drag.line); drag.line = nil end
end
local function StartDrag(button)
    if drag.obj then return end   -- (already dragging: the press watcher below and the game's OnDragStart can both start one)
    local last = LastKey(button.uniquevalue) or ""
    local kind, obj, label
    local n = last:match("^rule(%d+)$")
    if n then
        kind, obj = "rule", ns.rules and ns.rules[tonumber(n)]
        if obj and drag.DragNested(obj) then obj = nil end   -- cue / condition rows are moved with their rule
        if obj then
            label = obj.name
            if not label or label == "" then local ok, sn = pcall(C_Spell.GetSpellName, obj.spellID); label = ok and sn or ("Rule " .. n) end
        end
    elseif last:match("^f%d") then
        kind, obj = "folder", FolderById(last)
        label = obj and obj.name
    end
    if not obj then return end
    drag.kind, drag.obj, drag.src, drag.hl, drag.line, drag.label, drag.shown = kind, obj, button, nil, nil, tostring(label or ""), nil
    if not dragFrame then
        dragFrame = CreateFrame("Frame", nil, UIParent)
        dragFrame:SetFrameStrata("TOOLTIP")
        dragFrame:SetSize(200, 20)
        dragFrame.bg = dragFrame:CreateTexture(nil, "BACKGROUND")
        dragFrame.bg:SetAllPoints(); dragFrame.bg:SetColorTexture(0, 0, 0, 0.7)
        dragFrame.text = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        dragFrame.text:SetPoint("CENTER")
    end
    dragFrame.text:SetText(drag.label)
    dragFrame:SetWidth(math.max(80, dragFrame.text:GetStringWidth() + 16))
    dragFrame:Show()
    dragFrame:SetScript("OnUpdate", function(self)
        local ok, err = pcall(drag.tick, self)
        if not ok then drag.fail(err) end
    end)
end
function drag.TargetName(anchor, target)
    if anchor then return tostring(anchor.name or "") end
    local f = target and FolderById(target)
    return f and tostring(f.name or "") or "the top level"
end
-- the per-frame part of a drag; any error here ends the drag (see drag.fail) instead of repeating every frame
drag.tick = function(self)
    local x, y = GetCursorPosition()
    local sc = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc + 12, y / sc - 4)
    local tb = RowUnderCursor(drag.src and drag.src.obj)
    local ok, target, anchor, where
    if tb and tb ~= drag.src then
        local isF = (LastKey(tb.uniquevalue) or ""):match("^f%d") ~= nil
        ok, target, anchor, where = DropTarget(tb, drag.kind, drag.obj, drag.DropZone(tb, drag.kind, isF))
    end
    local wantHL = (ok and where == "into") and tb or nil
    local wantLine = (ok and where ~= "into") and tb or nil
    if drag.hl ~= wantHL then
        if drag.hl then drag.hl:UnlockHighlight() end
        if wantHL then wantHL:LockHighlight() end
        drag.hl = wantHL
    end
    if drag.line and drag.line:GetParent() ~= wantLine then drag.line:Hide(); drag.line = nil end
    if wantLine then
        local t = drag.DropLine(wantLine)
        t:ClearAllPoints()
        local edge = (where == "before") and "TOP" or "BOTTOM"
        t:SetPoint(edge .. "LEFT", wantLine, edge .. "LEFT", 0, 0); t:SetPoint(edge .. "RIGHT", wantLine, edge .. "RIGHT", 0, 0)
        t:Show(); drag.line = t
    end
    -- the floating label says what a drop here would do
    local say = drag.label
    if ok then
        say = say .. "  |cffaaaaaa" .. (where == "before" and "above " or where == "after" and "below " or "into ") .. "|r" .. drag.TargetName(anchor, target)
    end
    if drag.shown ~= say then
        drag.shown = say
        self.text:SetText(say)
        self:SetWidth(math.max(80, self.text:GetStringWidth() + 16))
    end
end
-- a drag, drop or arrow move failed: put everything back, say what failed, and keep the message in the saved error log
drag.fail = function(err)
    drag.kind, drag.obj = nil, nil
    if dragFrame then dragFrame:Hide(); dragFrame:SetScript("OnUpdate", nil) end
    drag.ClearMarks()
    ns.Print("moving a row failed and was canceled: " .. tostring(err))
    if ns.CaptureError then pcall(ns.CaptureError, "XayaUI move: " .. tostring(err), debugstack and debugstack(2) or "", "XUI-E013") end
    pcall(Notify)
end
local function StopDrag(button)
    local kind, obj = drag.kind, drag.obj
    if not obj then return end
    drag.kind, drag.obj = nil, nil
    if dragFrame then dragFrame:Hide(); dragFrame:SetScript("OnUpdate", nil) end
    drag.ClearMarks()
    local tb = RowUnderCursor(button.obj)
    if not tb or tb == button then return end
    local isF = (LastKey(tb.uniquevalue) or ""):match("^f%d") ~= nil
    local ok, target, anchor, where = DropTarget(tb, kind, obj, drag.DropZone(tb, kind, isF))
    if not ok then return end
    if kind == "rule" and ns.MultiHas and ns.MultiHas(obj) and ns.MultiCount() > 1 then ns.MultiMove(target); return end   -- dragging one selected rule moves them all
    if not ns.DragPlace(kind, obj, target, anchor, where) then return end
    ns.MarkDirty(); pcall(ns.RefreshAllVisuals); Notify()   -- the on-screen preview / dynamic groups lay out in rule order: redo it now
    ns.SelectKeep(kind == "rule" and RulePath(obj) or FolderPath(obj))
end
-- #343 (Xaya 2026-11-06: the broken drag is "rule rows in the sidebar"; pressing a row and dragging does "Nothing at all"): the game's
-- own OnDragStart never reached the rows in her game (the cause was not found offline: the rows are registered for dragging and nothing
-- covers them). So the drag no longer depends on it: a left press on a row arms a watcher; once the mouse has moved DRAG_PX pixels with
-- the button still held, the drag starts; releasing the button drops it (wherever the mouse is). OnDragStart / OnDragStop stay as a
-- second way in (StartDrag / StopDrag ignore a second start or stop). A press that does not move is a plain click, as before.
drag.DRAG_PX = 6
function drag.Arm(button)
    if drag.obj or not GetCursorPosition then return end
    local x0, y0 = GetCursorPosition()
    local sc = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    drag.watch = drag.watch or CreateFrame("Frame")
    local w = drag.watch
    w.btn, w.x0, w.y0, w.sc = button, x0, y0, sc
    w:SetScript("OnUpdate", function(self)
        local ok, err = pcall(function()
            local held = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
            if not held then
                self:SetScript("OnUpdate", nil)
                if drag.obj then StopDrag(self.btn) end
                return
            end
            if not drag.obj then
                local x, y = GetCursorPosition()
                if math.abs(x - self.x0) + math.abs(y - self.y0) >= drag.DRAG_PX * self.sc then StartDrag(self.btn) end
            end
        end)
        if not ok then self:SetScript("OnUpdate", nil); drag.fail(err) end
    end)
end
ns.DragForTest = { start = StartDrag, stop = StopDrag, zone = drag.DropZone, target = DropTarget, state = drag, arm = drag.Arm }   -- tests/drag_drop_run.py

-------------------------------------------------------------------------------
-- Reorder arrows: small up / down triangles at the left of every rule and folder row under All Rules.
-- A rule moves among the rules of its own folder (position in ns.rules); a folder moves among the folders that share its
-- parent (position in ns.folders). Folders are always listed above rules, as before. Nothing else about a row changes.
-------------------------------------------------------------------------------
ns.REORDER_W = 13
do   -- scoped: the main chunk is near Lua's 200-local limit
local function RuleGroupKey(r) return (r.folder and FolderById(r.folder)) and r.folder or false end
local function IsNestedOutcome(r) return (r.parentUid and ns.FindParentRule and ns.FindParentRule(r)) and true or false end
local function FolderParentKey(f) return (f.parent and FolderById(f.parent)) and f.parent or false end

-- Until the first move, top-level order is the legacy one (default categories fixed, the rest by list position). The first
-- move bakes that order into ns.folders and switches ui.folderOrdered on, so list position is the order from then on.
function ns.FolderSortOrder(f, k, dpos)
    local ui = PlatS.ui
    if ui and ui.folderOrdered then return 100 + k end
    return dpos and (10 + dpos) or (100 + k)
end
local function NormalizeFolderOrder()
    local ui = PlatS.ui
    if not ui or ui.folderOrdered then return end
    local keyed = {}
    for k, f in ipairs(ns.folders) do
        local _, dpos = ns.DefaultFolderInfo(f.default)
        keyed[#keyed + 1] = { f = f, k = k, key = dpos and (10 + dpos) or (100 + k) }
    end
    table.sort(keyed, function(a, b) if a.key ~= b.key then return a.key < b.key end return a.k < b.k end)
    for i, e in ipairs(keyed) do ns.folders[i] = e.f end
    ui.folderOrdered = true
end
ns.NormalizeFolderOrder = NormalizeFolderOrder   -- drag and drop (above) places groups by list position too

-- returns kind, obj, list of sibling indices, position in that list
local function Siblings(uv)
    local last = LastKey(uv) or ""
    -- in the Loaded / Not Loaded views only the rows shown there count as neighbors (so an arrow always moves the row visibly)
    local first = tostring(uv or ""):match("^([^\001]+)")
    local scope = (first == "loaded" or first == "notloaded" or first == "disabled") and first or nil
    -- (Options 0.6.69, REQUEST-LOG A15 P-16) while one redraw of the sidebar rows runs (ns.OptionsApi.memo, set by WithCueMemo) the
    -- rules do not change: each rule's scope, group and parent are read once for all the rows instead of once per row (every row read
    -- every rule: three quarters of a click with 313 rules). Same lists, same order; each row gets its own copy.
    local M = ns.OptionsApi.memo
    local MS
    if M then
        local mk = "sib:" .. tostring(scope)
        MS = M[mk]
        if not MS then
            MS = { inScope = {}, nested = {}, gkey = {}, lists = {}, has = {} }
            if scope then MS.okc, MS.ctx = pcall(ns.ReadContext) end
            M[mk] = MS
        end
    end
    local okc, ctx
    if MS then okc, ctx = MS.okc, MS.ctx elseif scope then okc, ctx = pcall(ns.ReadContext) end
    local function RuleInScope0(r)
        if not scope then return true end
        return okc and ns.RuleScope(r, ctx) == scope or false
    end
    local function RuleInScope(r)
        if not MS then return RuleInScope0(r) end
        local v = MS.inScope[r]
        if v == nil then v = RuleInScope0(r); MS.inScope[r] = v end
        return v
    end
    local function Nested(r)
        if not MS then return IsNestedOutcome(r) end
        local v = MS.nested[r]
        if v == nil then v = IsNestedOutcome(r); MS.nested[r] = v end
        return v
    end
    local function GKey(r)
        if not MS then return RuleGroupKey(r) end
        local v = MS.gkey[r]
        if v == nil then v = RuleGroupKey(r); MS.gkey[r] = v end
        return v
    end
    local function FolderInScope(f)
        if not scope then return true end
        local function has0(fid, depth)
            if depth > 16 then return false end
            for _, r in ipairs(ns.rules or {}) do
                if r.folder == fid and not Nested(r) and RuleInScope(r) then return true end
            end
            for _, x in ipairs(ns.folders or {}) do
                if x.parent == fid and has0(x.id, depth + 1) then return true end
            end
            return false
        end
        if not MS then return has0(f.id, 0) end
        local v = MS.has[f.id]
        if v == nil then v = has0(f.id, 0); MS.has[f.id] = v end
        return v
    end
    local n = last:match("^rule(%d+)$")
    if n then
        local idx = tonumber(n)
        local rule = ns.rules and ns.rules[idx]
        if not rule or Nested(rule) then return end
        local key, list, pos = GKey(rule), {}, nil
        local all = MS and MS.lists[key]
        if not all then
            all = {}
            for i, r in ipairs(ns.rules) do
                if not Nested(r) and GKey(r) == key and RuleInScope(r) then all[#all + 1] = i end
            end
            if MS then MS.lists[key] = all end
        end
        for j = 1, #all do list[j] = all[j]; if ns.rules[all[j]] == rule then pos = j end end
        return "rule", rule, list, pos
    end
    local f = last:match("^f%d") and FolderById(last)
    if f then
        if scope == "disabled" then return end   -- the Disabled list is flat: its group rows are not neighbors of each other, so no up / down arrows
        local key, list, pos = FolderParentKey(f), {}, nil
        for i, x in ipairs(ns.folders) do
            if FolderParentKey(x) == key and (x == f or FolderInScope(x)) then list[#list + 1] = i; if x == f then pos = #list end end
        end
        return "folder", f, list, pos
    end
end

ns.SiblingsForTest = Siblings   -- read by tests/disabled_tree_run.py (arrows on Disabled group rows)
local function ReorderRow(button, dir)
    local kind, obj, list, pos = Siblings(button.uniquevalue)
    if not obj or not pos then return end
    local tree = button.obj
    local st = tree and (tree.status or tree.localstatus)
    local selLast = LastKey(st and st.selected)
    local sn = selLast and selLast:match("^rule(%d+)$")
    local selRule = sn and ns.rules and ns.rules[tonumber(sn)] or nil   -- keep the current selection on the same rule
    if kind == "folder" then
        NormalizeFolderOrder()
        local _
        _, obj, list, pos = Siblings(button.uniquevalue)
        if not pos then return end
    end
    local other = list[pos + dir]
    if not other then return end
    local arr = (kind == "rule") and ns.rules or ns.folders
    local i = list[pos]
    arr[i], arr[other] = arr[other], arr[i]
    ns.MarkDirty(); pcall(ns.RefreshAllVisuals); Notify()   -- the on-screen preview / dynamic groups lay out in rule order: redo it now
    if selRule then ns.SelectKeep(RulePath(selRule)) end
end

ns.ReorderRowForTest = ReorderRow   -- read by tests/disabled_tree_run.py (a reorder redraws the on-screen preview)
local function MakeReorderArrow(button, dir)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(ns.REORDER_W, 9)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b.dir = dir
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetSize(13, 13)
    b.tex:SetPoint("CENTER")
    local up, down = "Interface\\Buttons\\Arrow-Up-Up", "Interface\\Buttons\\Arrow-Down-Up"
    local base = dir < 0 and up or down
    b.tex:SetTexture(base)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.tex:SetPoint("CENTER", 0, -1) end end)
    b:SetScript("OnMouseUp", function(self) self.tex:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnClick", function(self) local ok, e = pcall(ReorderRow, button, self.dir); if not ok then drag.fail(e) end end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self:IsEnabled() then
            GameTooltip:SetText(self.dir < 0 and "Move up" or "Move down")
            GameTooltip:AddLine("Changes the order within this list. Rules inside a group stay in that group.", 1, 1, 1, true)
        else
            GameTooltip:SetText(self.dir < 0 and "Already first" or "Already last")
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- called from DecorateButton; sets button.xuiReorderOn when the row reserves the arrow slot
function ns.PaintReorder(button, level, x)
    local uv = tostring(button.uniquevalue or "")
    local root0 = uv:match("^([^\001]+)")
    local slot = (root0 == "all" or root0 == "loaded" or root0 == "notloaded" or root0 == "disabled") and level >= 2 and not uv:find("\001smart", 1, true)
    button.xuiReorderOn = slot
    local kind, obj, list, pos
    if slot then kind, obj, list, pos = Siblings(uv) end
    if not (slot and obj and pos) then
        if button.xuiUp then button.xuiUp:Hide(); button.xuiDown:Hide() end
        return
    end
    if not button.xuiUp then button.xuiUp = MakeReorderArrow(button, -1); button.xuiDown = MakeReorderArrow(button, 1) end
    local function paint(b, can, anchor, dy)
        b:ClearAllPoints(); b:SetPoint("CENTER", button, "LEFT", x + 8, dy)
        b:SetEnabled(can)
        b.tex:SetDesaturated(not can)
        b.tex:SetAlpha(can and 1 or 0.3)
        b:Show()
    end
    paint(button.xuiUp, pos > 1, nil, 6)
    paint(button.xuiDown, pos < #list, nil, -6)
end
end

-------------------------------------------------------------------------------
-- Right-click context menu on sidebar rows (rename / duplicate / move to / delete ...)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Copy / paste settings between rules (choose exactly which sections; nothing is pasted by default)
-------------------------------------------------------------------------------
local ruleClip = nil          -- { name = "...", data = <deep copy of the source rule> }
local pasteSel = {}           -- section key -> true (shared by the Info tab, folder pages and the right-click menu)
-- Paste Settings is a tree: every leaf is one section (a tick box); a branch has "All of ..." plus its leaves. Leaves keep short keys.
-- Visual leaves list the cue-display keys they copy; "vTex" is the catch-all for every other display key (texture art etc.).
ns.PASTE_VIS = {
    vSize    = { "w", "h", "iconW", "iconH", "keepAspect", "zoom" },
    vColor   = { "alpha", "texAlpha", "oocAlpha", "recolor", "desaturate", "tint", "additive", "desatOnCD" },
    vRotate  = { "rotation", "flipH", "flipV" },
    vFade    = { "fadeGrey", "fadeMode", "fadeColor", "fadeAlpha", "fadeAlphaMin", "fadeAlphaMax" },
    vFlash   = { "flash" },
    vFill    = { "fill" },
    vOverlay = { "overlay" },
    vGlow    = { "glow" },
    vOutline = { "outline" },
    vBorder  = { "border", "bg" },
    vOnBar   = { "requireOnBar" },
    vHoverTip = { "hoverTip" },   -- "Show tooltip on hover" (own tick box; no longer rides along with "Texture / art")
}
ns.PASTE_VIS_SKIP = { text = true, count = true, absorb = true, x = true, y = true, anchor = true, anchorPlace = true, point = true }
ns.PASTE_TREE = {
    { "Triggers", {
        { "Cooldown trigger", {
            { "idsCd", "Spell ID and Max Charges" }, { "stCd", "Cooldown State" } } },
        { "Buff / Aura trigger", {
            { "idsBuff", "Aura ID" }, { "stBuff", "Buff State" } } },
        { "extra", "Additional Triggers (whole list + combine mode)" },
        { "XROWS" },
        { "activation", "Activation mode + trigger order" },
        { "talents", "Talents (requirement mode + list)" },
    } },
    { "load", "Load Conditions" },
    { "actions", "Actions (chat message, glow, custom code)" },
    { "conditions", "Conditions (list + the cues each fires)" },
    { "Cues", {
        { "cues", "Cue list (replaces the rule's cues)" },
        { "Display", {
            { "vTex", "Texture / art" }, { "vSize", "Size, aspect, zoom" }, { "vColor", "Color, tint, opacity" },
            { "vRotate", "Rotation and flip" }, { "vFade", "Fade (as the buff runs out)" }, { "vFlash", "Flash" },
            { "vFill", "Progress-bar wipe" }, { "vOverlay", "Overlay layer" }, { "vGlow", "Glow" },
            { "vOutline", "Outline" }, { "vBorder", "Border and background" }, { "vOnBar", "Only show while on an action bar" }, { "vHoverTip", "Show tooltip on hover" } } },
        { "position", "Position (X / Y)" },
        { "Text", {
            { "textDur", "Buff Duration" }, { "textCnt", "Stacks / Charges Count" }, { "textAbs", "Shield / Absorb Amount" } } },
        { "Audio", {
            { "sound", "Sound and Channel" }, { "sndRep", "Repeat" } } },
    } },
}
local PASTE_ORDER, PASTE_LABELS = {}, {}
do
    local function walk(list)
        for _, n in ipairs(list) do
            if type(n[2]) == "table" then walk(n[2])
            elseif n[2] then PASTE_ORDER[#PASTE_ORDER + 1] = n[1]; PASTE_LABELS[n[1]] = n[2] end
        end
    end
    walk(ns.PASTE_TREE)
end
local function PasteApply(key, dst, src)
    local C = ns.Copy
    if key == "idsCd" then
        dst.spellID, dst.maxCharges, dst.useCooldown, dst.cdName = src.spellID, src.maxCharges, src.useCooldown, src.cdName
        dst.exactSpell = src.exactSpell
    elseif key == "idsBuff" then
        dst.buffID, dst.useBuff, dst.buffName = src.buffID, src.useBuff, src.buffName
        dst.buffAlt = src.buffAlt and ns.Copy(src.buffAlt) or nil
    elseif key == "activation" then dst.trigMode, dst.trigOrder = src.trigMode, src.trigOrder and C(src.trigOrder) or nil
    elseif key == "actions" then dst.actions = src.actions and C(src.actions) or nil
    elseif key == "stCd" then
        dst.cdState, dst.countGCD, dst.countLOC = src.cdState, src.countGCD, src.countLOC
        dst.cdTimeOp, dst.cdTimeSec, dst.cdChargeOp, dst.cdChargeVal = src.cdTimeOp, src.cdTimeSec, src.cdChargeOp, src.cdChargeVal
    elseif key == "stBuff" then dst.buffState, dst.buffTimeOp, dst.buffTimeSec = src.buffState, src.buffTimeOp, src.buffTimeSec
    elseif key == "talents" then dst.talents, dst.talentMode = C(src.talents or {}), src.talentMode
    elseif key == "extra" then dst.extra = C(src.extra or { list = {} })
    elseif key == "load" then dst.load = C(src.load or {})
    elseif key == "vTex" then
        local claimed = {}
        for _, ks in pairs(ns.PASTE_VIS) do for _, k in ipairs(ks) do claimed[k] = true end end
        for k, val in pairs(src.visual or {}) do
            if not claimed[k] and not ns.PASTE_VIS_SKIP[k] and not (dst.isCue and (k == "enabled" or k == "trigger")) then dst.visual[k] = C(val) end
        end
    elseif ns.PASTE_VIS[key] then
        for _, k in ipairs(ns.PASTE_VIS[key]) do
            if src.visual then dst.visual[k] = (src.visual[k] ~= nil) and C(src.visual[k]) or nil end
        end
    elseif key == "position" then dst.visual.x, dst.visual.y = src.visual.x, src.visual.y
    elseif key == "textDur" then dst.visual.text = C(src.visual.text)
    elseif key == "textCnt" then dst.visual.count = C(src.visual.count)
    elseif key == "textAbs" then dst.visual.absorb = C(src.visual.absorb)
    elseif key == "sound" then dst.sound = C(src.sound)
    elseif key == "sndRep" then dst.repeatSec = src.repeatSec end
end
local function PasteSelectedLabels()
    local l = {}
    for _, k in ipairs(PASTE_ORDER) do if pasteSel[k] then l[#l + 1] = PASTE_LABELS[k] end end
    for k in pairs(pasteSel) do if type(k) == "string" and k:match("^xr%d+$") then l[#l + 1] = "Additional trigger " .. k:sub(3) end end
    return l
end
local function PasteCount() local n = 0; for _, v in pairs(pasteSel) do if v then n = n + 1 end end return n end
-- Rules are split into a trigger side (the rule), CONDITIONS and CUES (hidden child rules, see Cues.lua / Outcomes.lua). A clip keeps all
-- three. ns functions, not locals: this file is near Lua's 200-locals limit.
function ns.MakeClip(rule)
    local clip = { name = rule.name, data = ns.Copy(rule), cues = {}, conds = {} }
    if rule.uid and not rule.parentUid and not rule.isCue then
        for _, c in ipairs(ns.CuesOf(rule)) do clip.cues[#clip.cues + 1] = ns.Copy(c) end
        for _, c in ipairs(ns.ConditionsOf(rule)) do clip.conds[#clip.conds + 1] = ns.Copy(c) end
    end
    return clip
end
function ns.PasteDropChildren(list)
    for _, c in ipairs(list) do
        for i, r in ipairs(ns.rules) do if r == c then table.remove(ns.rules, i); break end end
        pcall(ns.DropVisual, c)
    end
end
function ns.PasteCues(dst, clip)
    dst.uid = dst.uid or ns.NewUID()
    ns.PasteDropChildren(ns.CuesOf(dst))
    for _, c in ipairs(clip.cues) do
        local n = ns.Copy(c)
        n.uid, n.parentUid, n.folder = nil, dst.uid, dst.folder
        n.name = tostring(dst.name or "") .. " (cue)"
        ns.rules[#ns.rules + 1] = n
        pcall(ns.RefreshVisual, n)
    end
end
function ns.PasteConditions(dst, clip)
    dst.uid = dst.uid or ns.NewUID()
    ns.PasteDropChildren(ns.ConditionsOf(dst))
    for _, c in ipairs(clip.conds) do
        local n = ns.Copy(c)
        n.uid, n.parentUid, n.folder = nil, dst.uid, dst.folder
        ns.rules[#ns.rules + 1] = n
    end
end
-- a condition may only fire cues the rule really has; returns how many references had to be dropped
function ns.PasteCleanRefs(dst)
    local keys, dropped = {}, 0
    for _, c in ipairs(ns.CuesOf(dst)) do if c.cueKey then keys[c.cueKey] = true end end
    for _, cond in ipairs(ns.ConditionsOf(dst)) do
        if type(cond.thenCues) == "table" then
            local keep = {}
            for _, k in ipairs(cond.thenCues) do if keys[k] then keep[#keep + 1] = k else dropped = dropped + 1 end end
            cond.thenCues = (#keep > 0) and keep or nil
            ns.NormalizeCues(cond)
        end
    end
    return dropped
end
-- Appearance / audio sections go onto the cues of the target: each copied cue is matched with a cue of the SAME KIND in list order.
-- A rule with no cues (older rule) counts as one display / one sound. Returns pairs applied, copied parts left without a partner.
function ns.PasteLook(dst, clip, sel, apply)
    local VIS = { "vTex", "vSize", "vColor", "vRotate", "vFade", "vFlash", "vFill", "vOverlay", "vGlow", "vOutline", "vBorder", "vOnBar", "vHoverTip", "position", "textDur", "textCnt", "textAbs" }
    local wantVis = false
    for _, k in ipairs(VIS) do if sel[k] then wantVis = true end end
    if not wantVis and not sel.sound and not sel.sndRep then return 0, 0 end
    local function isSnd(c) return c.cueKind == "sound" or c.cueKind == "speech" end
    local function isVis(c) return c.cueKind ~= "sound" and c.cueKind ~= "speech" and c.cueKind ~= "custom" end
    local dCues = dst.uid and ns.CuesOf(dst) or {}
    local done, skipped = 0, 0
    local function run(pred, keys)
        local srcs, byKind = {}, {}
        for _, c in ipairs(clip.cues) do if pred(c) then srcs[#srcs + 1] = c end end
        if #clip.cues == 0 then srcs[1] = clip.data end
        for _, c in ipairs(dCues) do if pred(c) then local k = c.cueKind or "?"; byKind[k] = byKind[k] or {}; table.insert(byKind[k], c) end end
        local used = {}
        for _, s in ipairs(srcs) do
            local d
            if #clip.cues == 0 then   -- an older rule: its own display / sound goes to the target's first matching cue, or to the target itself
                if #dCues == 0 then d = dst else for _, c in ipairs(dCues) do if pred(c) then d = c; break end end end
            else
                local list = byKind[s.cueKind or "?"]
                local n = used[s.cueKind or "?"] or 0
                d = list and list[n + 1]
                used[s.cueKind or "?"] = n + 1
            end
            if not d and #clip.cues > 0 and dst.uid and not dst.isCue and s.cueKind and ns.NewCueRule then
                -- the copied rule has more cues of this kind than the target (a second / third texture layer): make the missing cue, carrying the
                -- source cue's name and key so conditions copied later can still point at it
                d = ns.NewCueRule(dst, s.cueKind)
                if d then
                    d.cueName = s.cueName
                    ns.pasteCreated = (ns.pasteCreated or 0) + 1
                end
            end
            if d then
                for _, k in ipairs(keys) do if sel[k] then apply(k, d, s) end end
                pcall(ns.RefreshVisual, d)
                done = done + 1
            else skipped = skipped + 1 end
        end
    end
    if wantVis then run(isVis, VIS) end
    if sel.sound or sel.sndRep then run(isSnd, { "sound", "sndRep" }) end
    return done, skipped
end
-- returns true if something was pasted
local function PasteInto(dst)
    if not ruleClip or PasteCount() == 0 or dst.parentUid or dst.isCue then return false end
    if ns.IsEditLocked and ns.IsEditLocked(dst) then ns.pasteNotes[#ns.pasteNotes + 1] = "'" .. tostring(dst.name) .. "' is edit-locked, skipped"; return false end
    local sel, clip = pasteSel, ruleClip
    for _, k in ipairs({ "idsCd", "idsBuff", "stCd", "stBuff", "talents", "extra", "activation", "load", "actions" }) do if sel[k] then PasteApply(k, dst, clip.data) end end
    if not sel.extra then   -- single additional triggers are ADDED to the target's list (its own triggers stay)
        local src = clip.data.extra and clip.data.extra.list
        for i = 1, (src and #src or 0) do
            if sel["xr" .. i] then
                dst.extra = type(dst.extra) == "table" and dst.extra or { list = {} }
                dst.extra.list = dst.extra.list or {}
                dst.extra.list[#dst.extra.list + 1] = ns.Copy(src[i])
            end
        end
    end
    if sel.cues then ns.PasteCues(dst, clip) end
    if sel.conditions then ns.PasteConditions(dst, clip) end
    if sel.cues or sel.conditions then
        local dropped = ns.PasteCleanRefs(dst)
        if dropped > 0 then ns.pasteNotes[#ns.pasteNotes + 1] = dropped .. " condition link(s) to cues this rule does not have were removed (tick Cues too to bring the cues along)" end
    end
    ns.pasteCreated = 0
    local _, skipped = ns.PasteLook(dst, clip, sel, PasteApply)
    if ns.pasteCreated > 0 then ns.pasteNotes[#ns.pasteNotes + 1] = ns.pasteCreated .. " extra cue(s) were created on '" .. tostring(dst.name) .. "' to hold the copied layers (no condition fires them yet: tick Conditions + Cues to copy those too)" end
    if skipped > 0 then ns.pasteNotes[#ns.pasteNotes + 1] = skipped .. " copied display / sound part(s) had no cue of the same kind on '" .. tostring(dst.name) .. "' (tick Cues to copy the cues themselves)" end
    pcall(ns.RefreshVisual, dst)
    ns.MarkDirty()
    return true
end
ns.pasteNotes = {}
local function PasteSummary()
    return table.concat(PasteSelectedLabels(), "; ")
end
StaticPopupDialogs["XAYAUI_CONFIRM"] = {
    text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(self, data) if data and data.cb then data.cb() end end,
}
local function PopupEditBox(self) return self.editBox or (self.GetEditBox and self:GetEditBox()) end
StaticPopupDialogs["XAYAUI_RENAME"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, maxLetters = 64, timeout = 0, whileDead = true,
    hideOnEscape = true, preferredIndex = 3,
    OnShow = function(self, data)
        local eb = PopupEditBox(self)
        if eb then eb:SetText((data and data.current) or ""); eb:HighlightText() end
    end,
    OnAccept = function(self, data)
        local eb = PopupEditBox(self)
        local t = eb and eb:GetText()
        if t and t ~= "" and data and data.cb then data.cb(t) end
    end,
    EditBoxOnEnterPressed = function(eb)
        local p = eb:GetParent()
        local t, data = eb:GetText(), p.data
        p:Hide()
        if t and t ~= "" and data and data.cb then data.cb(t) end
    end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
}
local function ShowPopup(which, text, data)
    local dlg = StaticPopup_Show(which, text, nil, data)
    if dlg then dlg:SetFrameStrata("TOOLTIP") end   -- the options window is FULLSCREEN_DIALOG; keep the popup above it
end
local function AskRename(current, cb) ShowPopup("XAYAUI_RENAME", "Rename", { current = current, cb = cb }) end
local function AskConfirm(text, cb) ShowPopup("XAYAUI_CONFIRM", text, { cb = cb }) end

-- Export one rule (right-click > Export): shows the export text in a popup, selected, ready for Ctrl+C.
StaticPopupDialogs["XAYAUI_EXPORT"] = {
    text = "%s", button1 = CLOSE, hasEditBox = true, editBoxWidth = 360, maxLetters = 0, timeout = 0, whileDead = true,
    hideOnEscape = true, preferredIndex = 3,
    OnShow = function(self, data)
        local eb = PopupEditBox(self)
        if eb then
            if eb.SetMaxLetters then eb:SetMaxLetters(0) end
            eb:SetText((data and data.text) or ""); eb:HighlightText(); eb:SetFocus()
        end
    end,
    EditBoxOnTextChanged = function(eb)
        local data = eb:GetParent().data
        if data and data.text and eb:GetText() ~= data.text then eb:SetText(data.text); eb:HighlightText() end   -- read-only
    end,
    EditBoxOnEnterPressed = function(eb) eb:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
}
ns.UI.ExportFolder = function(fold)
    local snap = ns.Share_SnapshotGroup(fold, tostring(fold.name or "Group"))
    local txt, err = ns.Share.Encode("rules", snap)
    if not txt then ns.Print("could not export '" .. tostring(fold.name) .. "': " .. tostring(err)); return end
    ShowPopup("XAYAUI_EXPORT", "Export of the group '" .. tostring(fold.name) .. "': " .. #snap.folders .. " group(s), " .. #snap.rules .. " rule(s) including their cues and conditions"
        .. "\nCtrl+C to copy, then paste it into Import / Export > Import rules (or the Import button) on the other character or account.", { text = txt })
end
ns.UI.ExportRule = function(rule)
    local snap = ns.Share_SnapshotRule(rule, tostring(rule.name or "Rule"))
    local txt, err = ns.Share.Encode("rules", snap)
    if not txt then ns.Print("could not export '" .. tostring(rule.name) .. "': " .. tostring(err)); return end
    local n = #snap.rules - 1
    ShowPopup("XAYAUI_EXPORT", "Export of '" .. tostring(rule.name) .. "'" .. (n > 0 and (" (+" .. n .. " condition" .. (n > 1 and "s" or "") .. ")") or "")
        .. "\nCtrl+C to copy, then paste it into Import / Export > Import rules on the other character or account.", { text = txt })
end

-- Display <-> Sound: build equivalent rules in the other bucket from what each rule tracks (spell, aura, talents, states).
-- Load conditions start blank and the new rule starts disabled with its one output ticked, so turning it on is a single switch.
local function ConvertFolder(src, mode)
    local toKey = (src.default == "display") and "sound" or "display"
    local dst
    for _, f in ipairs(ns.folders) do if not f.parent and f.default == toKey then dst = f; break end end
    if not dst then ns.Print("that category group is missing - create a group for it under Smart Categories first"); return end
    local rules = FolderRules(src.id)
    if #rules == 0 then ns.Print("nothing inside '" .. tostring(src.name) .. "' to " .. mode); return end
    local sub = ns.NewFolder((mode == "copy" and "Copied from " or "Moved from ") .. tostring(src.name), dst.id)
    for _, r in ipairs(rules) do
        local n = ns.NewRule()
        n.name = r.name
        for _, k in ipairs({ "spellID", "maxCharges", "cdState", "buffID", "buffState", "buffTimeOp", "buffTimeSec", "talentMode" }) do n[k] = r[k] end
        n.buffAlt = r.buffAlt and ns.Copy(r.buffAlt) or nil
        n.talents = ns.Copy(r.talents or {})
        n.extra = ns.Copy(r.extra or { list = {} })
        n.folder = sub.id
        n.enabled = false
        if toKey == "sound" then n.sound.enabled, n.visual.enabled = true, false
        else n.visual.enabled, n.sound.enabled = true, false end
        ns.rules[#ns.rules + 1] = n
        pcall(ns.RefreshVisual, n)
    end
    if mode == "transform" then
        for _, r in ipairs(rules) do
            for idx, x in ipairs(ns.rules) do if x == r then table.remove(ns.rules, idx); break end end
            pcall(ns.DropVisual, r)
        end
    end
    ns.MarkDirty(); Notify()
    ns.Print((mode == "copy" and "copied " or "moved ") .. #rules .. " rule(s) into '" .. tostring(dst.name) .. "' (disabled; turn them on and pick a " .. (toKey == "sound" and "sound" or "display") .. ")")
end

local function SelectRoot() ns.GoHome() end

local function DeleteRule(rule)
    ns.RecycleRule(rule)   -- to the Recycle Bin, with its cues and conditions (XayaUI/RecycleBin.lua)
    ns.MarkDirty(); Notify(); SelectRoot()
end
local function DuplicateRule(rule)
    local c = ns.Copy(rule)
    c.name = ((rule.name and rule.name ~= "") and rule.name or "Rule") .. " Copy"
    if ns.CloneOutcomes then ns.CloneOutcomes(rule, c) end
    ns.rules[#ns.rules + 1] = c
    pcall(ns.RefreshVisual, c)
    ns.MarkDirty(); Notify()
    ns.SelectKeep(RulePath(c))
end
-- copies a folder with its rules and subfolders (children keep their names; the top copy gets " Copy")
local function DuplicateFolder(f, parentId, top)
    local nf = ns.NewFolder(f.name .. (top and " Copy" or ""), parentId)
    for _, r in ipairs(ns.rules) do
        if r.folder == f.id then
            local c = ns.Copy(r); c.folder = nf.id
            ns.rules[#ns.rules + 1] = c
            pcall(ns.RefreshVisual, c)
            if ns.RememberCopy then ns.RememberCopy(r, c) end
        end
    end
    if ns.RemapCopies then ns.RemapCopies() end
    local kids = {}
    for _, ff in ipairs(ns.folders) do if ff.parent == f.id and ff ~= nf then kids[#kids + 1] = ff end end
    for _, ff in ipairs(kids) do DuplicateFolder(ff, nf.id, false) end
    return nf
end
local function DeleteFolder(f)
    ns.RecycleFolder(f)   -- contents move up one level; the group goes to the Recycle Bin (XayaUI/RecycleBin.lua)
    ns.MarkDirty(); Notify(); SelectRoot()
end

function ns.DeleteFolderById(id) local f = FolderById(id); if f then DeleteFolder(f) end end
-- Deletes the group, every group nested in it and every rule inside them (and those rules' cues / conditions).
function ns.DeleteFolderAll(f)
    local _, n = ns.RecycleFolderAll(f)   -- the group, its nested groups and their rules: ONE Recycle Bin item (XayaUI/RecycleBin.lua)
    ns.MarkDirty(); Notify(); SelectRoot()
    return n or 0
end
function ns.DeleteFolderAllById(id) local f = FolderById(id); if f then return ns.DeleteFolderAll(f) end end

local function AddMoveMenu(root, obj, kind)
    local multi = kind == "rule" and ns.MultiHas and ns.MultiHas(obj) and ns.MultiCount() > 1
    local sub = root:CreateButton(multi and ("Move " .. ns.MultiCount() .. " Selected To") or "Move To")
    sub:CreateButton("Top Level (Smart Categories)", function()
        if multi then ns.MultiMove(nil); return end
        if kind == "rule" then obj.folder = nil else obj.parent = nil end
        ns.MarkDirty(); pcall(ns.RefreshAllVisuals); Notify()
    end)
    local _, fOrder = FolderValues()
    for _, fid in ipairs(fOrder) do
        local f = fid ~= "none" and FolderById(fid)
        if f and not (kind == "folder" and IsInFolder(f.id, obj.id)) then
            local depth = 0
            for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then depth = depth + 1 end end
            depth = depth - 1
            sub:CreateButton(string.rep("    ", depth) .. f.name, function()
                if multi then ns.MultiMove(f.id); return end
                if kind == "rule" then obj.folder = f.id else obj.parent = f.id end
                ns.MarkDirty(); pcall(ns.RefreshAllVisuals); Notify()
                if kind == "rule" then ns.SelectKeep(RulePath(obj))
                else ns.SelectKeep(FolderPath(obj)) end
            end)
        end
    end
end

-- Copy / paste lives only in the right-click menu. Ticks are session-only; nothing is ticked by default, so nothing is overwritten
-- until sections are chosen. Returning MenuResponse.Refresh keeps the submenu open while ticking (unverified in game: if the
-- game ignores it, the menu simply closes after each tick).
function ns.PasteMenuBuild(menu, nodes, refresh)
    local function leaves(list, out)
        for _, n in ipairs(list) do
            if type(n[2]) == "table" then leaves(n[2], out) elseif n[2] then out[#out + 1] = n[1] end
        end
        return out
    end
    for _, n in ipairs(nodes) do
        if n[1] == "XROWS" then
            local rows = ruleClip and ruleClip.data.extra and ruleClip.data.extra.list or {}
            if #rows > 0 then
                local sm = menu:CreateButton("Single additional triggers (added to the target's)")
                for i, row in ipairs(rows) do
                    local def = ns.TRIGGER_TYPES and ns.TRIGGER_TYPES[row.type]
                    local nm = (type(row.name) == "string" and row.name:match("%S")) and (row.name .. ":  ") or ""
                    local key = "xr" .. i
                    sm:CreateCheckbox(("Trigger %d:  %s%s"):format(i + 2, nm, tostring((def and (def.label or def.name)) or row.type or "?")),
                        function() return pasteSel[key] and true or false end,
                        function() pasteSel[key] = (not pasteSel[key]) or nil; return refresh end)
                end
            end
        elseif type(n[2]) == "table" then
            local sm = menu:CreateButton(n[1])
            local ks = leaves(n[2], {})
            sm:CreateCheckbox("All of " .. n[1],
                function() for _, k in ipairs(ks) do if not pasteSel[k] then return false end end return true end,
                function()
                    local all = true
                    for _, k in ipairs(ks) do if not pasteSel[k] then all = false end end
                    for _, k in ipairs(ks) do pasteSel[k] = (not all) or nil end
                    return refresh
                end)
            sm:CreateDivider()
            ns.PasteMenuBuild(sm, n[2], refresh)
        else
            local k = n[1]
            menu:CreateCheckbox(n[2],
                function() return pasteSel[k] and true or false end,
                function() pasteSel[k] = (not pasteSel[k]) or nil; return refresh end)
        end
    end
end
local function AddPasteMenu(root, label, getTargets, describe)
    local sub = root:CreateButton(label)
    local refresh = MenuResponse and MenuResponse.Refresh
    sub:CreateTitle(ruleClip and ("Copied: " .. tostring(ruleClip.name)) or "Nothing copied yet (use Copy Settings)")
    local okP, errP = pcall(ns.PasteMenuBuild, sub, ns.PASTE_TREE, refresh)   -- a fault in the paste tree must never take the whole right-click menu down
    if not okP then ns.Print("paste menu error: " .. tostring(errP)) end
    sub:CreateDivider()
    sub:CreateButton("Paste Selected Sections", function()
        if not ruleClip then ns.Print("nothing copied yet: right-click a rule and choose Copy Settings first") return end
        if PasteCount() == 0 then ns.Print("no sections selected: tick the sections to paste in the Paste Settings menu first") return end
        local targets = getTargets()
        local warn = ((pasteSel.idsCd or pasteSel.idsBuff) and #targets > 1) and "\n|cffff8040Trigger IDs are selected: every one of these rules will track the same spell and aura.|r" or ""
        if pasteSel.conditions then warn = warn .. "\n|cffff8040Conditions replace the target's conditions. They refer to the rule's triggers and cues, so tick those sections too if the target's differ.|r" end
        if pasteSel.cues then warn = warn .. "\n|cffff8040Cues replace every cue of the target.|r" end
        AskConfirm("Overwrite these sections on " .. describe() .. " with settings from '" .. tostring(ruleClip.name) .. "'?\n" .. PasteSummary() .. warn,
            function()
                local n = 0
                wipe(ns.pasteNotes)
                for _, r in ipairs(targets) do if PasteInto(r) then n = n + 1 end end
                Notify(); ns.Print(("pasted into %d rule(s)"):format(n))
                for _, note in ipairs(ns.pasteNotes) do ns.Print("paste note: " .. note) end
            end)
    end)
end

local function RowMenu(button, root)
    local last = LastKey(button.uniquevalue) or ""
    local n = last:match("^rule(%d+)$")
    local rule = n and ns.rules and ns.rules[tonumber(n)]
    if rule then
        root:CreateTitle((rule.name and rule.name ~= "") and rule.name or "Rule")
        if ns.IsEditLocked(rule) then
            root:CreateTitle("|cffff6060Edits blocked|r")
            root:CreateButton("Duplicate", function() DuplicateRule(rule) end)
            root:CreateButton("Export", function() ns.UI.ExportRule(rule) end)
            root:CreateButton("Copy Settings", function() ruleClip = ns.MakeClip(rule); Notify() end)
            return true
        end
        root:CreateButton("Rename", function()   -- edits in the sidebar row; the popup is only the fallback when the row is gone
            if not (ns.SidebarRenameLater and ns.SidebarRenameLater(button)) then AskRename(rule.name, function(t) rule.name = t; pcall(ns.RefreshVisual, rule); ns.MarkDirty(); Notify() end) end
        end)
        root:CreateButton("Duplicate", function() DuplicateRule(rule) end)
        root:CreateButton("Export", function() ns.UI.ExportRule(rule) end)
        root:CreateButton("Copy Settings", function() ruleClip = ns.MakeClip(rule); Notify(); ns.Print("copied settings of '" .. tostring(rule.name) .. "'") end)
        AddPasteMenu(root, "Paste Settings", function() return { rule } end, function() return "'" .. tostring(rule.name) .. "'" end)
        root:CreateButton(rule.enabled and "Disable" or "Enable", function()
            rule.enabled = not rule.enabled; pcall(ns.RefreshVisual, rule); ns.MarkDirty(); Notify()
        end)
        if ns.MultiHas and ns.MultiHas(rule) and ns.MultiCount() > 1 and #ns.MultiLinkTargets() >= 2 then
            local n, linked = ns.MultiCount(), ns.MultiLinked()
            root:CreateButton(linked and ("Unlink " .. n .. " Selected") or ("Link " .. n .. " Selected (move together)"), function() ns.MultiLink(not linked) end)
        end
        AddMoveMenu(root, rule, "rule")
        root:CreateDivider()
        root:CreateButton("Delete", function() AskConfirm("Delete the rule '" .. tostring(rule.name) .. "'? " .. ns.RecycleBinNote(), function() DeleteRule(rule) end) end)
        return true
    end
    local fold = last:match("^f%d") and FolderById(last)
    if fold then
        root:CreateTitle(fold.name)
        root:CreateButton("Rename", function()
            if not (ns.SidebarRenameLater and ns.SidebarRenameLater(button)) then AskRename(fold.name, function(t) fold.name = t; ns.MarkDirty(); Notify() end) end
        end)
        root:CreateButton("New Rule Here", function()
            StartNewRule(fold.id)
        end)
        root:CreateButton("New Nested Group", function()
            local nf = ns.NewFolder("Group", fold.id)
            local path = { ns.PlaceNewGroup(nf, ns.ScopeOfUV(button.uniquevalue)) }   -- same list as the parent row
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, unpack(path))
        end)
        root:CreateButton("Duplicate", function()
            local nf = DuplicateFolder(fold, fold.parent, true)
            ns.MarkDirty(); Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, FolderPath(nf))
        end)
        if not fold.parent and (fold.default == "display" or fold.default == "sound") then
            local to = (fold.default == "display") and "Sound" or "Display"
            root:CreateDivider()
            root:CreateButton("Copy " .. fold.name .. " to " .. to .. " Cues", function() ConvertFolder(fold, "copy") end)
            root:CreateButton("Transform " .. fold.name .. " to " .. to .. " Cues", function()
                AskConfirm("Transform every rule in '" .. tostring(fold.name) .. "' into " .. to .. " Cues? The originals are removed.", function() ConvertFolder(fold, "transform") end)
            end)
            root:CreateDivider()
        end
        root:CreateButton("Enable All Rules Inside", function() for _, r in ipairs(FolderTopRules(fold.id)) do r.enabled = true; pcall(ns.RefreshVisual, r) end; ns.MarkDirty(); Notify() end)
        root:CreateButton("Disable All Rules Inside", function() for _, r in ipairs(FolderTopRules(fold.id)) do r.enabled = false; pcall(ns.RefreshVisual, r) end; ns.MarkDirty(); Notify() end)
        root:CreateButton("Export Group", function() ns.UI.ExportFolder(fold) end)
        AddPasteMenu(root, "Paste Settings Into Rules Here", function() return FolderRules(fold.id) end,
            function() return "every rule in '" .. tostring(fold.name) .. "' (and its nested groups)" end)
        AddMoveMenu(root, fold, "folder")
        root:CreateDivider()
        root:CreateButton("Delete Group (Contents Move Up)", function()
            AskConfirm("Delete the group '" .. fold.name .. "'? Its rules and nested groups are kept and move up one level. " .. ns.RecycleBinNote(), function() DeleteFolder(fold) end)
        end)
        root:CreateButton("|cffff6060Delete Group and All Contents|r", function()
            local n = #FolderTopRules(fold.id)
            AskConfirm("Delete the group '" .. fold.name .. "' AND everything inside it: " .. n .. " rule(s) and all nested groups? They go to the Recycle Bin together as one item, for " .. ns.RecycleKeepLabel() .. ".", function() ns.DeleteFolderAll(fold) end)
        end)
        return true
    end
    n = last:match("^bar(%d+)$")
    local bar = n and ns.bars and ns.bars[tonumber(n)]
    if bar then
        root:CreateTitle(bar.name or "Buff Bar")
        root:CreateButton("Rename", function() AskRename(bar.name, function(t) bar.name = t; ns.Bars_Refresh(bar); ns.MarkDirty(); Notify() end) end)
        root:CreateButton("Duplicate", function()
            local c = ns.Copy(bar); c.name = (bar.name or "Buff bar") .. " Copy"
            ns.bars[#ns.bars + 1] = c; ns.Bars_Refresh(c); ns.MarkDirty(); Notify()
        end)
        root:CreateDivider()
        root:CreateButton("Delete", function()
            AskConfirm("Delete the bar '" .. tostring(bar.name) .. "'?", function()
                for idx, b in ipairs(ns.bars) do if b == bar then table.remove(ns.bars, idx); break end end
                ns.Bars_Drop(bar); ns.MarkDirty(); Notify()
                pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allbars")
            end)
        end)
        return true
    end
    n = last:match("^box(%d+)$")
    local box = n and ns.qolBoxes and ns.qolBoxes[tonumber(n)]
    if box then
        root:CreateTitle(box.name or "Stats Box")
        root:CreateButton("Rename", function() AskRename(box.name, function(t) box.name = t; ns.QoL_Refresh(box); ns.MarkDirty(); Notify() end) end)
        root:CreateButton("Duplicate", function()
            local c = ns.Copy(box); c.name = (box.name or "Stats") .. " Copy"; c.y = (c.y or 0) - 30
            ns.qolBoxes[#ns.qolBoxes + 1] = c; ns.QoL_Refresh(c); ns.MarkDirty(); Notify()
        end)
        root:CreateDivider()
        root:CreateButton("Delete", function()
            AskConfirm("Delete the box '" .. tostring(box.name) .. "'?", function()
                for idx, b in ipairs(ns.qolBoxes) do if b == box then table.remove(ns.qolBoxes, idx); break end end
                ns.QoL_Drop(box); ns.MarkDirty(); Notify()
                pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allqol")
            end)
        end)
        return true
    end
    if last == "all" then
        root:CreateTitle("Smart Categories")
        root:CreateButton("New Rule", function()
            StartNewRule(nil)
        end)
        root:CreateButton("New Group", function()
            local nf = ns.NewFolder("Group")
            Notify()
            pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, ns.FolderLoadedPath(nf))
        end)
        return true
    end
    return false
end

-- Blizzard's Menu code (Blizzard_Menu/Menu.lua) gives a menu the strata FULLSCREEN_DIALOG, or TOOLTIP when its owner region is
-- at TOOLTIP strata. The options window is also FULLSCREEN_DIALOG and sits higher in level, so the menu opened behind it.
-- Fix: use an invisible TOOLTIP-strata frame laid over the clicked row as the menu's owner region.
local menuOwner
local function MenuOwner(button)
    if not menuOwner then
        menuOwner = CreateFrame("Frame", nil, UIParent)
        menuOwner:SetFrameStrata("TOOLTIP")
        menuOwner:EnableMouse(false)
    end
    menuOwner:ClearAllPoints()
    menuOwner:SetPoint("TOPLEFT", button, "TOPLEFT")
    menuOwner:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
    menuOwner:Show()
    return menuOwner
end

local function ShowRowMenu(button)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.Print("the context menu needs the game's MenuUtil, which is not available") return end
    local shown = false
    local ok, err = pcall(MenuUtil.CreateContextMenu, MenuOwner(button), function(_, root)
        -- Menu.lua runs root-registered acquired callbacks for every menu and submenu it opens, so submenus (e.g. Move To) are
        -- raised above the options window too.
        if root.AddMenuAcquiredCallback then
            root:AddMenuAcquiredCallback(function(menu)
                if menu and menu.SetFrameStrata then
                    pcall(menu.SetFrameStrata, menu, "TOOLTIP")
                    if menu.Raise then pcall(menu.Raise, menu) end
                end
            end)
        end
        shown = RowMenu(button, root)
    end)
    if not ok then ns.Print("context menu error: " .. tostring(err)) end
end

-- Right-click on EMPTY space in the Rules sidebar (below the last row, or between rows): New Rule / New Group / New Dynamic Group at the cursor.
-- Rows keep their own menu (RowMenu); this only fires when the click lands on the sidebar frame itself.
function ns.ShowBlankMenu(frame)
    local tab = ns.CurrentTab and ns.CurrentTab()
    if tab ~= "cooldowns" and tab ~= "smartcat" then return end   -- only the Rules sidebar; QoL and Settings trees have no rule list
    if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.Print("the context menu needs the game's MenuUtil, which is not available") return end
    local function NewGroup(dynamic)
        local nf = ns.NewFolder(dynamic and "Dynamic Group" or "Group")
        if dynamic then nf.cType = "dynamic" end
        ns.MarkDirty(); Notify()
        pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, ns.FolderLoadedPath(nf))
    end
    local ok, err = pcall(MenuUtil.CreateContextMenu, MenuOwner(frame), function(_, root)
        if root.AddMenuAcquiredCallback then
            root:AddMenuAcquiredCallback(function(menu)
                if menu and menu.SetFrameStrata then
                    pcall(menu.SetFrameStrata, menu, "TOOLTIP")
                    if menu.Raise then pcall(menu.Raise, menu) end
                end
            end)
        end
        root:CreateTitle("Create")
        root:CreateButton("New Rule", function() StartNewRule(nil) end)
        root:CreateButton("New Group", function() NewGroup(false) end)
        root:CreateButton("New Dynamic Group", function() NewGroup(true) end)
    end)
    if not ok then ns.Print("context menu error: " .. tostring(err)) end
end
-- hook the sidebar frame of a tree once; called from the row decorator, which knows its tree (button.obj)
function ns.HookSidebarBlank(tree)
    local tf = tree and tree.treeframe
    if not tf or tf.xuiBlankHook then return end
    tf.xuiBlankHook = true
    tf:EnableMouse(true)   -- rows and the search box sit on top and take their own clicks; only free space reaches the frame
    tf:HookScript("OnMouseUp", function(self, mouse)
        if mouse == "RightButton" then pcall(ns.ShowBlankMenu, self) end
    end)
end

-- Header rows (the root row and every top-level folder) get a tinted banner so each reads as its own group.
local BANNER_TINT = {
    root = { 1, 0.78, 0 }, loaded = { 0.1, 0.85, 0.75 }, notloaded = { 0.95, 0.2, 0.2 }, disabled = { 0.55, 0.55, 0.6 }, display = { 0.1, 0.5, 1 }, sound = { 0.1, 0.75, 0.3 }, hybrid = { 1, 0.5, 0.1 }, advanced = { 0.75, 0.25, 1 }, smart = { 0.3, 0.8, 1 }, cursor = { 0.95, 0.35, 0.75 }, other = { 0.7, 0.7, 0.75 },
}
local function BannerTint(uv)
    local last = uv and tostring(uv):match("([^\001]*)$")
    if last == "all" or last == "allbars" or last == "allqol" or last == "allcursor" or last == "autopop" then return BANNER_TINT.root end
    if last == "loaded" then return BANNER_TINT.loaded end
    if last == "notloaded" then return BANNER_TINT.notloaded end
    if last == "disabled" then return BANNER_TINT.disabled end
    if last == "smart" then return BANNER_TINT.smart end
    local f = last and ns.FolderById and ns.FolderById(last)
    if f and not f.parent then
        return (type(f.default) == "string" and BANNER_TINT[f.default]) or BANNER_TINT.other
    end
end
function ns.HotPath(sel, prefix)   -- prefix is the selected path, above it, or inside it
    if not sel or not prefix then return false end
    -- only the selected row itself (never its parents or the rows inside it); the root rows (All Rules, Loaded, ...) never light up
    local last = sel:match("([^\001]+)$")
    if last == "all" or last == "loaded" or last == "notloaded" or last == "disabled" or last == "smart" or last == "autopop"
        or last == "allbars" or last == "allqol" or last == "allcursor" then return false end
    return sel == prefix
end
-- Tree-chart guide bars: every row inside a top-level folder repeats that folder's color as a vertical bar at the
-- left edge (a continuation of the folder's own banner bar), and each deeper folder level adds one more, lighter
-- and thinner bar, indented one step. Rows directly under the Loaded / Not Loaded roots continue that root's color.
local function PaintGuides(button)
    local guides = button.xuiGuides
    local bars = {}
    local uv = button.uniquevalue and tostring(button.uniquevalue) or nil
    local tb = ns.TREE_BAR   -- one muted color for every bar
    if uv then
        -- ONE bar only, for the grandparent group of the selected item (e.g. Defensives for a rule inside HUD),
        -- drawn on the rows inside that group. No selection or a shallow selection = no bars.
        local segs = {}
        for seg in uv:gmatch("[^\001]+") do segs[#segs + 1] = seg end
        local sel = ns.TREE_BARS_ENABLED and ns.SelectedUV(button) or nil   -- vertical tree bars are switched off (set ns.TREE_BARS_ENABLED = true to bring them back)
        if sel then
            local ss = {}
            for seg in sel:gmatch("[^\001]+") do ss[#ss + 1] = seg end
            local g = #ss - 2
            if g >= 1 and #segs > g then
                local same = true
                for i = 1, g do if segs[i] ~= ss[i] then same = false; break end end
                if same then
                    local isAll, smart = (segs[1] == "all" or segs[1] == "loaded" or segs[1] == "notloaded" or segs[1] == "disabled"), false
                    for i = 1, g do if segs[i]:find("^smart") then smart = true end end
                    local shift = (isAll and g >= 2 and not smart) and ((ns.REORDER_W or 0) + 11) or 0
                    bars[#bars + 1] = { x = 8 * g - 6 + shift + 7, w = 2, r = tb[1], g = tb[2], b = tb[3], a = 1 }
                end
            end
        end
    end
    if #bars == 0 and not guides then return end
    guides = guides or {}
    button.xuiGuides = guides
    for i, bar in ipairs(bars) do
        local t = guides[i]
        if not t then
            t = button:CreateTexture(nil, "BACKGROUND", nil, -1)
            guides[i] = t
        end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", button, "TOPLEFT", bar.x, 0)
        t:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", bar.x, 0)
        t:SetWidth(bar.w)
        t:SetColorTexture(bar.r, bar.g, bar.b, bar.a)
        t:Show()
    end
    for i = #bars + 1, #guides do guides[i]:Hide() end
end

-- Right-hand pair on rule / folder rows: [movement lock] [edit lock]
function ns.MakeSideToggle(button, kind)
    local b = CreateFrame("Button", nil, button)
    b:SetSize(15, 15)
    b:SetFrameLevel(button:GetFrameLevel() + 3)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.kind = kind
    if kind == "edit" then
        b.tex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        b.slash = b:CreateTexture(nil, "OVERLAY")
        b.slash:SetColorTexture(1, 0.15, 0.15, 1)
        b.slash:SetSize(20, 2)
        b.slash:SetPoint("CENTER")
        b.slash:SetRotation(math.rad(45))
    end
    b:SetScript("OnClick", function(self)
        if self.kind == "move" and self.xuiMoveFolder then
            ns.SetGroupUnlocked(self.xuiMoveFolder, not self.xuiOn)   -- a group row moves the GROUP (one outline), not each display
        elseif self.kind == "move" then
            ns.SetMoveUnlocked(self.xuiObjs, not self.xuiOn)
        elseif self.xuiFolder then
            local f = self.xuiFolder
            f.editLocked = (not f.editLocked) or nil
        else
            for _, r in ipairs(self.xuiObjs or {}) do r.editLocked = (not self.xuiOn) or nil end
        end
        ns.MarkDirty()
        if ns.DecorateTrees then ns.DecorateTrees() end
        Notify()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.kind == "move" then
            GameTooltip:SetText(self.xuiOn and "Movement unlocked" or "Movement locked")
            if self.xuiMoveFolder then
                GameTooltip:AddLine(self.xuiOn and "Drag the orange outline on screen to move the whole group. Click to lock it again." or "Click to show one outline around this group so you can drag the whole group.", 1, 1, 1, true)
            else
                GameTooltip:AddLine(self.xuiOn and "Drag the displays on screen. Click to lock them again." or "Click to unlock this row's on-screen displays so you can drag them.", 1, 1, 1, true)
            end
        else
            GameTooltip:SetText(self.xuiOn and "Edits blocked" or "Editable")
            GameTooltip:AddLine(self.xuiOn and "Settings here are read-only. Click to allow edits again." or "Click to block edits: settings here become read-only.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function ns.PaintSide(button, rules, vis, folder)
    local showEdit = folder ~= nil or #rules > 0
    local showMove = vis and #vis > 0
    local off = 4
    local fixed = not button.xuiTwoRow
    local C = ns.OptionsApi.SIDE_COL
    if showEdit then
        if not button.xuiEdit then button.xuiEdit = ns.MakeSideToggle(button, "edit") end
        local b = button.xuiEdit
        local locked
        if folder then locked = folder.editLocked and true or false
        else
            locked = true
            for _, r in ipairs(rules) do if not r.editLocked then locked = false; break end end
        end
        b.xuiOn, b.xuiObjs, b.xuiFolder = locked, rules, folder
        b.slash:SetShown(locked)
        b.tex:SetDesaturated(locked)
        b.tex:SetAlpha(locked and 0.7 or 1)
        b:ClearAllPoints(); b:SetPoint("RIGHT", button, "RIGHT", -(fixed and C.note or off), button.xuiTwoRow and -9 or 0)
        b:Show()
        off = fixed and (C.note + 19) or (off + 19)
    elseif button.xuiEdit then button.xuiEdit:Hide() end
    if showMove then
        if not button.xuiMove then button.xuiMove = ns.MakeSideToggle(button, "move") end
        local b = button.xuiMove
        local n = 0
        for _, r in ipairs(vis) do if ns.IsMoveUnlocked(r) then n = n + 1 end end
        b.xuiOn, b.xuiObjs = (n == #vis), vis
        b.xuiMoveFolder = folder
        if folder and ns.IsGroupUnlocked then n = ns.IsGroupUnlocked(folder) and #vis or 0; b.xuiOn = (n == #vis) end
        b.tex:SetTexture(n == 0 and ns.LOCK_ICON or ns.MOVE_ICON)   -- our own flat icons (Xaya 2026-11-06: white lock, gold mover)
        b.tex:SetAlpha(n == 0 and 0.85 or (n == #vis and 1 or 0.6))
        b:ClearAllPoints(); b:SetPoint("RIGHT", button, "RIGHT", -(fixed and C.lock or off), button.xuiTwoRow and -9 or 0)
        b:Show()
        off = fixed and (C.lock + 19) or (off + 19)
    elseif button.xuiMove then button.xuiMove:Hide() end
    if button.text then button.text:SetPoint("RIGHT", button, "RIGHT", -math.max(off, button.xuiIconR or 0), 2) end
    button.xuiTextR = math.max(off, button.xuiIconR or 0)   -- #369: the name's right inset (Skin.lua ns.EnsureNameRoom)
end

local ROW_TOGGLES = {
    allqol = { title = "Stat Tracking on / off",
        tip = "Unticked: every stats box is hidden on screen and nothing is listed here. Your boxes are kept.",
        get = function() return ns.QoLOn() end,
        set = function(v) QolS.qol = QolS.qol or {}; QolS.qol.enabled = v; pcall(ns.QoL_RefreshAll) end },
    allcursor = { title = "Cursor Tracker on / off",
        tip = "Ticked: a texture follows your mouse cursor (off by default). Your settings are kept when unticked.",
        get = function() return ns.CursorOn() end,
        set = function(v) QolS.cursor = QolS.cursor or {}; QolS.cursor.enabled = v; if ns.Cursor_Apply then ns.Cursor_Apply() end end },
    ["allcursor\001reminders"] = { title = "At-Cursor Reminders on / off",
        tip = "Ticked: the spell icons of your rules' displays are shown next to the mouse cursor (which rules: see this pane). Off by default; your choices are kept when unticked.",
        get = function() return QolS.cursor and QolS.cursor.remOn and true or false end,
        set = function(v) QolS.cursor = QolS.cursor or {}; QolS.cursor.remOn = v; if ns.CursorReminders_Apply then ns.CursorReminders_Apply() end end },
    allbars = { title = "Buff Bars on / off",
        tip = "Unticked: every buff bar is hidden on screen and nothing is listed here. Your bars are kept.",
        get = function() return ns.BarsOn() end,
        set = function(v) CoreS.barGroup.enabled = v; pcall(ns.Bars_RefreshAll) end },
}

-- Left cluster, in order:  [collapse arrow] [eye] [headphone]  text
-- Multi-select delete: Ctrl+click toggles a rule row, Shift+click selects the visible rule rows between the last clicked row and
-- this one (either direction). Selected rows get a purple wash in every list they appear in. "Delete N selected" (bottom-left of the window) deletes them
-- after a confirmation. A plain click on any row, or "Clear selection", drops the selection.
do
    local sel, anchor = {}, nil   -- sel[rule] = true
    local function RuleOfButton(button)
        local last = tostring(button.uniquevalue or ""):match("([^\001]+)$") or ""
        local n = tonumber(last:match("^rule(%d+)$"))
        return n and ns.rules and ns.rules[n]
    end
    function ns.MultiCount() local n = 0; for _ in pairs(sel) do n = n + 1 end; return n end
    function ns.MultiReset() wipe(sel); anchor = nil end
    function ns.MultiHas(rule) return sel[rule] and true or false end
    -- "Link N Selected (move together)" (Xaya, 2026-11-06: "linking aura functionality not possible in the drop down menu"; her answer
    -- "Link N selected"). A link joins displays (Visual.lua ns.LinkAura: dragging one moves the others), so the selected rules' displays
    -- are linked: each rule's display cues (ns.PreviewTargets), or the rule itself when it draws its own display.
    function ns.MultiLinkTargets()
        local out, seen = {}, {}
        for _, r in ipairs(ns.rules or {}) do   -- list order, so the result does not depend on table order
            if sel[r] then
                for _, t in ipairs((ns.PreviewTargets and ns.PreviewTargets(r)) or { r }) do
                    if not seen[t] and t.visual and t.visual.enabled then seen[t] = true; out[#out + 1] = t end
                end
            end
        end
        return out
    end
    function ns.MultiLinked()
        local t = ns.MultiLinkTargets()
        if #t < 2 then return false end
        local id = t[1].link
        if not id then return false end
        for _, o in ipairs(t) do if o.link ~= id then return false end end
        return true
    end
    function ns.MultiLink(on)
        local t = ns.MultiLinkTargets()
        if on then
            for i = 2, #t do ns.LinkAura(t[i], t[1]) end
        else
            for _, o in ipairs(t) do ns.UnlinkAura(o) end
        end
        ns.MarkDirty(); Notify()
        ns.Print(on and ("linked %d display(s): dragging one moves them all (Shift-drag: one alone)"):format(#t) or "unlinked the selected displays")
    end
    -- move every selected rule into group fid (nil = top level)
    function ns.MultiMove(fid)
        local fo = fid and FolderById(fid)
        if fo and ns.IsCategoryRoot(fo) then ns.Print("rules cannot be placed into a Smart Category"); return end
        local n, skipped = 0, 0
        for r in pairs(sel) do
            if ns.IsEditLocked(r) then skipped = skipped + 1   -- audit D44: a locked rule stays where it is
            elseif r.folder ~= fid then r.folder = fid; n = n + 1 end
            -- outcomes embedded in a rule follow their parent's group (same rule as the single-rule move)
        end
        if skipped > 0 then ns.Print(("%d edit-locked rule(s) were not moved (unlock them in the sidebar to move them)."):format(skipped)) end
        local keep = {}
        for r in pairs(sel) do if not ns.IsEditLocked(r) then keep[#keep + 1] = r end end
        ns.MultiReset()
        ns.MarkDirty(); pcall(ns.RefreshAllVisuals); Notify()
        if ns.DecorateTrees then ns.DecorateTrees() end
        local g = fid and FolderById(fid)
        ns.Print(("moved %d rule(s) to %s"):format(#keep, g and tostring(g.name) or "the top level"))
    end
    -- "Move to..." menu for the selection bar
    function ns.MultiMoveMenu(owner)
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
        pcall(MenuUtil.CreateContextMenu, MenuOwner(owner), function(_, root)
            if root.AddMenuAcquiredCallback then
                root:AddMenuAcquiredCallback(function(menu)
                    if menu and menu.SetFrameStrata then pcall(menu.SetFrameStrata, menu, "TOOLTIP"); if menu.Raise then pcall(menu.Raise, menu) end end
                end)
            end
            root:CreateTitle("Move " .. ns.MultiCount() .. " selected rule(s) to")
            root:CreateButton("Top Level (no group)", function() ns.MultiMove(nil) end)
            local _, fOrder = FolderValues()
            for _, fid in ipairs(fOrder) do
                local f = fid ~= "none" and FolderById(fid)
                if f then
                    local depth = 0
                    for _, c in ipairs(FolderChain(f)) do if not ns.CueTransparent(c) then depth = depth + 1 end end
                    root:CreateButton(string.rep("    ", depth - 1) .. tostring(f.name), function() ns.MultiMove(f.id) end)
                end
            end
        end)
    end
    function ns.MultiClear() ns.MultiReset(); if ns.DecorateTrees then ns.DecorateTrees() end end
    function ns.MultiClick(button, mouse)
        if mouse ~= "LeftButton" then return end
        local ctrl, shift = IsControlKeyDown(), IsShiftKeyDown()
        local rule = RuleOfButton(button)
        if not (ctrl or shift) then
            -- a plain click drops the selection and becomes the start point for the next Shift+click (the row still opens as usual)
            if next(sel) then wipe(sel); if ns.DecorateTrees then ns.DecorateTrees() end end
            if rule then anchor = rule end
            return
        end
        if not rule then return end
        if shift and anchor and anchor ~= rule and button.obj and button.obj.buttons then
            -- range from the start point to this row, either direction; if the start rule is listed twice, take the nearer row
            local btns, hits, target = button.obj.buttons, {}, nil
            for i, b in ipairs(btns) do
                if b:IsShown() then
                    if RuleOfButton(b) == anchor then hits[#hits + 1] = i end
                    if b == button then target = i end
                end
            end
            if target and #hits > 0 then
                local from = hits[1]
                for _, i in ipairs(hits) do if math.abs(i - target) < math.abs(from - target) then from = i end end
                for i = math.min(from, target), math.max(from, target) do
                    local b = btns[i]
                    local r = b:IsShown() and RuleOfButton(b)
                    if r then sel[r] = true end
                end
                if ns.DecorateTrees then ns.DecorateTrees() end
                return
            end
        end
        sel[rule] = (not sel[rule]) or nil
        anchor = rule
        if ns.DecorateTrees then ns.DecorateTrees() end
    end
    function ns.MultiPaint(button)
        local rule = RuleOfButton(button)
        local on = rule and sel[rule]
        if on and not button.xuiMultiTex then
            button.xuiMultiTex = button:CreateTexture(nil, "BACKGROUND", nil, 1)
            button.xuiMultiTex:SetAllPoints()
            button.xuiMultiTex:SetColorTexture(0.75, 0.25, 1, 0.38)
        end
        if button.xuiMultiTex then button.xuiMultiTex:SetShown(on and true or false) end
    end
    function ns.MultiDelete()
        local list, skipped = {}, 0
        for r in pairs(sel) do if ns.IsEditLocked(r) then skipped = skipped + 1 else list[#list + 1] = r end end   -- audit D44
        if skipped > 0 then ns.Print(("%d edit-locked rule(s) are left out (unlock them in the sidebar to delete them)."):format(skipped)) end
        if #list == 0 then return end
        StaticPopup_Show("XAYAUI_CONFIRM", ("Delete %d selected rule(s)? Each goes to the Recycle Bin for %s and can be restored on its own."):format(#list, ns.RecycleKeepLabel()), nil, { cb = function()
            ns.RecycleRules(list)
            ns.MultiReset()
            ns.MarkDirty(); Notify(); SelectRoot()
        end })
    end
end

-- Rename a rule right in the sidebar: a text box over the row's name (double-click the row, or it opens by itself for a new rule).
function ns.SidebarRename(button)
    local rn = tostring(button.uniquevalue or ""):match("rule(%d+)$")
    local rule = rn and ns.rules and ns.rules[tonumber(rn)]
    local isFolder
    if not rule then   -- a group row: same box, renames the folder (an empty name keeps the old one)
        local fk = (LastKey(button.uniquevalue) or ""):match("^f%d") and LastKey(button.uniquevalue)
        rule = fk and FolderById(fk)
        isFolder = rule and true or nil
    end
    if not rule or ns.IsEditLocked(isFolder and { folder = rule.id } or rule) then return end   -- audit D44: a locked group is not renamed either
    local eb = button.xuiRenameEB
    if not eb then
        eb = CreateFrame("EditBox", nil, button)
        eb:SetAutoFocus(false); eb:SetHeight(22); eb:SetMaxLetters(60); eb:SetTextInsets(6, 6, 0, 0)
        eb:SetFontObject(GameFontHighlight)
        eb.bg = eb:CreateTexture(nil, "BACKGROUND"); eb.bg:SetAllPoints(); eb.bg:SetColorTexture(0, 0, 0, 1)
        eb.ln = eb:CreateTexture(nil, "ARTWORK"); eb.ln:SetHeight(1); eb.ln:SetPoint("BOTTOMLEFT"); eb.ln:SetPoint("BOTTOMRIGHT"); eb.ln:SetColorTexture(0.75, 0.25, 1, 1)
        eb:SetScript("OnEscapePressed", function(self) self.xuiCancel = true; self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEditFocusLost", function(self)
            local r = self.xuiRule
            self:Hide()
            if self.xuiCancel then self.xuiCancel = nil; return end
            if r then
                local t = tostring(self:GetText() or ""):sub(1, 60)
                if self.xuiIsFolder then
                    if t == "" then return end
                    r.name = t
                    ns.MarkDirty(); Notify()
                else
                    if t:match("^%s*$") then return end   -- audit D46: an empty name keeps the old one (as a group and the Rename popup do)
                    r.name = t
                    pcall(ns.RefreshVisual, r); ns.MarkDirty(); Notify()
                end
            end
        end)
        button.xuiRenameEB = eb
    end
    eb.xuiRule = rule; eb.xuiIsFolder = isFolder
    eb:SetFrameLevel(button:GetFrameLevel() + 8)
    eb:ClearAllPoints()
    local left = button.text and button.text:GetLeft() and button:GetLeft() and (button.text:GetLeft() - button:GetLeft() - 6) or 40
    eb:SetPoint("LEFT", button, "LEFT", math.max(4, left), 0)
    eb:SetPoint("RIGHT", button, "RIGHT", -52, 0)
    eb:SetText(tostring(rule.name or ""))
    eb:Show(); eb:SetFocus(); eb:HighlightText()
end

-- Called from the right-click menu: the menu closes after the click and takes keyboard focus with it, so the box opens a moment later.
function ns.SidebarRenameLater(button)
    if not (button and button.IsShown and button:IsShown() and C_Timer) then return false end
    C_Timer.After(0.1, function() if button:IsShown() then ns.SidebarRename(button) end end)
    return true
end

-- (P4b; Options 0.6.87 / XayaUI_Rules_Options 0.6.77) What the rules tree adds to the window's row painting (XayaUI_Options/TreePaint.lua
-- DecorateButton, which paints every tab's rows): moved here unchanged from the old DecorateButton, in the same order, as the hooks
-- TreePaint calls (ns.OptionsApi.TreePaint.rules, set at the end of this block). Without this addon (XayaUI Rules off) the window
-- paints its rows with none of these.
do
local R = {}
local ROOT_KEYS = { all = true, allbars = true, allqol = true, allcursor = true, loaded = true, notloaded = true, disabled = true, smart = true, autopop = true }
local UPPER_ROOTS = { all = true, loaded = true, notloaded = true, disabled = true, smart = true }
-- a row's tier (TreePaint RowTier): a root header, a sub-category (a nested group, a Smart Category), and whether its name is in capitals
-- (only ALL RULES, LOADED, NOT LOADED and SMART CATEGORIES)
function R.RowKind(uv, lastKey)
    local isRoot = ROOT_KEYS[uv] and true or false
    local fld = lastKey:match("^f%d") and ns.FolderById and ns.FolderById(lastKey) or nil
    local isSub = ((fld and fld.parent and true) or lastKey:match("^smart_") ~= nil or (fld and uv:find("\001smart\001", 1, true) ~= nil)) and true or false
    return isRoot, isSub, UPPER_ROOTS[uv] and true or false
end
R.BannerTint = BannerTint
-- the blank divider rows between All Rules and the Loaded / Not Loaded filters; the two spacer rows around NOT LOADED keep their
-- height but draw no line (Xaya, 2026-11-02)
function R.Spacer(button)
    local isSpacer = button.uniquevalue and (tostring(button.uniquevalue):match("([^\001]+)$") or ""):match("^spacer") ~= nil
    local spKey = button.uniquevalue and (tostring(button.uniquevalue):match("([^\001]+)$") or "") or ""
    if spKey == "spacer" or spKey == "spacer1" then isSpacer = false end
    return isSpacer
end
-- cue kinds: the eye only covers rules that have a display, the headphone only rules that have a sound
local function only(list, what)
    if not list then return list end
    local o = {}
    for _, x in ipairs(list) do if ns.KindHas(x, what) then o[#o + 1] = x end end
    return o
end
function R.Begin(button)
    PaintGuides(button)
    ns.MultiPaint(button)
    local vis, snd = Resolve(button.uniquevalue)
    local rawObjs = vis
    vis, snd = only(vis, "visual"), only(snd, "sound")
    local suv = tostring(button.uniquevalue or "")
    local inSC = (suv == "all" or suv:sub(1, 4) == "all\001")
    if inSC and (suv == "all" or suv == "all\001smart") then
        -- Smart Categories: the tab is the root, so its own row and the "by type" row are drawn as nothing
        button.xuiGone = true
        button:SetHeight(0.01); button:SetAlpha(0); button:EnableMouse(false)
        for _, k in ipairs({ "xuiChev", "xuiEye", "xuiHead", "xuiEdit", "xuiUp", "xuiDown", "xuiMove", "xuiBanner", "xuiBannerBar", "xuiSelTex", "xuiDivider", "xuiType", "xuiType2", "xuiSub", "xuiStatCheck", "xuiSwitchBox" }) do
            if button[k] and button[k].Hide then button[k]:Hide() end
        end
        return vis, snd, rawObjs, inSC, false, false, true
    end
    local hasIcons = (vis and #vis > 0) or (snd and #snd > 0)
    -- top-level roots (All Rules / Disabled / Smart Categories) carry no eye or headphone; their lock icons stay. Loaded and Not Loaded
    -- carry the eye (Resolve above; Xaya 2026-11-06)
    do
        local rootKey = tostring(button.uniquevalue or ""):match("([^\001]+)$")
        if rootKey == "all" or rootKey == "disabled" or rootKey == "smart" then hasIcons = false end
    end
    local rk0 = tostring(button.uniquevalue or ""):match("([^\001]+)$") or ""
    local isRootRow = (rk0 == "all" or rk0 == "loaded" or rk0 == "notloaded" or rk0 == "disabled" or rk0 == "smart" or (inSC and rk0:match("^smart_") ~= nil))
    return vis, snd, rawObjs, inSC, hasIcons, isRootRow, false
end
function R.Hooks(button)
    if button.obj and not (button.obj.treeframe and button.obj.treeframe.xuiBlankHook) then pcall(ns.HookSidebarBlank, button.obj) end
    if not button.xuiDrag then
        button.xuiDrag = true
        button:RegisterForDrag("LeftButton")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:HookScript("OnClick", function(self, mouse) ns.Trace("click"); if mouse == "RightButton" then ShowRowMenu(self) else ns.MultiClick(self, mouse) end end)
        button:HookScript("OnMouseDown", function(self, mouse) if mouse == "LeftButton" then local ok, e = pcall(drag.Arm, self); if not ok then drag.fail(e) end end end)   -- #343
        button:HookScript("OnDragStart", function(self) local ok, e = pcall(StartDrag, self); if not ok then drag.fail(e) end end)
        button:HookScript("OnDragStop", function(self) local ok, e = pcall(StopDrag, self); if not ok then drag.fail(e) end end)
    end
    if not button.xuiDblHooked then
        button.xuiDblHooked = true
        button:HookScript("OnDoubleClick", function(self) if ns.SidebarRename then ns.SidebarRename(self) end end)
    end
    if button.xuiRenameEB and button.xuiRenameEB:IsShown() and not button.xuiRenameEB:HasFocus() then button.xuiRenameEB:Hide() end
    do   -- a rule that was just created (no name yet) opens its name box in the sidebar
        local pr = ns.pendingRename
        local rnum = tostring(button.uniquevalue or ""):match("rule(%d+)$")
        if pr and rnum and ns.rules[tonumber(rnum)] == pr and C_Timer then
            ns.pendingRename = nil
            C_Timer.After(0.15, function() if button:IsShown() and ns.SidebarRename then ns.SidebarRename(button) end end)
        end
    end
end
function R.Reorder(button, level, x0)
    ns.PaintReorder(button, level, x0)
    if button.xuiReorderOn then x0 = x0 + ns.REORDER_W + 11 end   -- chevron and text sit right of the arrows
    return x0
end
-- QoL rows (Stat Tracking, Buff Bars): a left-aligned tick box is the on/off switch for the whole element
function R.RowToggle(button, x0)
    local CHEV_W = 16
    local toggleCfg = ROW_TOGGLES[tostring(button.uniquevalue or "")]
    if toggleCfg then
        if not button.xuiStatCheck then
            local cb = CreateFrame("CheckButton", nil, button, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb:SetFrameLevel(button:GetFrameLevel() + 3)
            cb:SetScript("OnClick", function(self)
                local cfg = ROW_TOGGLES[tostring(button.uniquevalue or "")]
                if not cfg then return end
                cfg.set(self:GetChecked() and true or false)
                ns.MarkDirty(); Notify()
            end)
            cb:SetScript("OnEnter", function(self)
                local cfg = ROW_TOGGLES[tostring(button.uniquevalue or "")]
                if not cfg then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(cfg.title)
                GameTooltip:AddLine(cfg.tip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
            button.xuiStatCheck = cb
        end
        local cb = button.xuiStatCheck
        cb:ClearAllPoints()
        cb:SetPoint("LEFT", button, "LEFT", x0 + CHEV_W + 4, 0)
        cb:SetChecked(toggleCfg.get())
        cb:Show()
    elseif button.xuiStatCheck then
        button.xuiStatCheck:Hide()
    end
    return toggleCfg
end
function R.Icons(button, vis, snd, hasIcons)
    local ICON_W = 17
    if hasIcons then
        if not button.xuiEye then
            button.xuiEye = MakeToggle(button, "visual")
            button.xuiHead = MakeToggle(button, "sound")
        end
        local function paint(b, objs, kind, sx)
            if not objs or #objs == 0 then b:Hide(); return end
            b.objs = objs
            b:ClearAllPoints()
            if button.xuiTwoRow then b:SetPoint("RIGHT", button, "RIGHT", -4, 9)   -- first row: the preview button at the right edge
            else b:SetPoint("RIGHT", button, "RIGHT", -sx, 0) end
            local st = GroupState(objs, kind)
            b.tex:SetTexture(ns.PreviewIcon(kind, st))   -- off: the slashed icon (still dimmed below)
            b.tex:SetDesaturated(st == 0)
            b.tex:SetAlpha(st == 1 and 1 or (st == 0.5 and 0.7 or 0.35))
            b:Show()
        end
        if button.xuiTwoRow then
            -- two rows: [preview] on top; [movement lock][edit lock] below it. The separate audio preview is gone;
            -- a rule that only plays a sound (no display) keeps one preview button, in the same place.
            paint(button.xuiEye, vis, "visual", 4 + 19 * 3)
            if vis and #vis > 0 then button.xuiHead:Hide() else paint(button.xuiHead, snd, "sound", 4 + 19 * 3) end
            button.xuiIconR = 4 + 17 + 3
        else
            -- (Options 0.6.64; UI-70 / UI-72, "copy the WA format") one preview column, just left of the open / close slot: the eye, or
            -- the headphone when the row only plays sounds (as on two-row rows); every row keeps the same columns
            local col = ns.OptionsApi.SIDE_COL.preview
            paint(button.xuiEye, vis, "visual", col)
            if vis and #vis > 0 then button.xuiHead:Hide() else paint(button.xuiHead, snd, "sound", col) end
            button.xuiIconR = ((vis and #vis > 0) or (snd and #snd > 0)) and (col + ICON_W + 3) or 0
        end
    elseif button.xuiEye then
        button.xuiEye:Hide(); button.xuiHead:Hide()
    end
end
-- Smart Categories: a small note under the rule's name says which of the regular groups it is in
function R.Note(button, inSC)
    local rk = tostring(button.uniquevalue or ""):match("([^\001]+)$")
    local note
    local rn = inSC and rk:match("^rule(%d+)$")
    if rn then
        local rr = ns.rules and ns.rules[tonumber(rn)]
        local ff = rr and rr.folder and ns.FolderById(rr.folder)
        if ff then
            local names = {}
            for _, c in ipairs(FolderChain(ff)) do if not ns.CueTransparent(c) then names[#names + 1] = tostring(c.name) end end
            note = (#names > 0) and table.concat(names, " / ") or "Top level"
        elseif rr then note = "Top level" end
    end
    return note
end
-- right side: movement lock + edit lock (rule, folder and all-rules rows only)
function R.Side(button, rawObjs, vis)
    local rules = {}
    for _, o in ipairs(rawObjs or {}) do if o.visual then rules[#rules + 1] = o end end
    local lastKey = tostring(button.uniquevalue or ""):match("([^\001]+)$") or ""
    -- audit D41: a rule whose displays are its cues listed only the cues here, so its lock left the rule itself editable
    local rn = lastKey:match("^rule(%d+)$")
    local own = rn and ns.rules and ns.rules[tonumber(rn)]
    if own then
        local has = false
        for _, o in ipairs(rules) do if o == own then has = true; break end end
        if not has then table.insert(rules, 1, own) end
    end
    local folder = lastKey:match("^f%d") and ns.FolderById(lastKey) or nil
    local vr = {}
    for _, o in ipairs(vis or {}) do if o.visual then vr[#vr + 1] = o end end
    ns.PaintSide(button, rules, vr, folder)
end
ns.OptionsApi.TreePaint = ns.OptionsApi.TreePaint or {}
ns.OptionsApi.TreePaint.rules = R
end

local function SelectedRule()
    if not AceConfigDialog.GetStatusTable then return nil end
    local tab = ns.CurrentTab()
    if tab ~= "cooldowns" and tab ~= "smartcat" then return nil end
    local st = { groups = ns.RulesTreeStatus() }
    local sel = st and st.groups and st.groups.selected
    local idx = sel and tonumber(tostring(sel):match("rule(%d+)"))
    return idx and ns.rules and ns.rules[idx]
end

function ns.SelectedRuleForUndo() return SelectedRule() end   -- Drafts.lua undo (Ctrl+Z) edits the rule selected in the sidebar

-- Selected group in the sidebar (last path segment is a group id), or nil.
function ns.SelectedGroup()
    if not AceConfigDialog.GetStatusTable then return nil end
    local tab = ns.CurrentTab()
    if tab ~= "cooldowns" and tab ~= "smartcat" then return nil end
    local st = { groups = ns.RulesTreeStatus() }
    local sel = st and st.groups and st.groups.selected
    local last = sel and tostring(sel):match("([^\001]+)$")
    return last and FolderById(last) or nil
end
-- Del key: delete the multi-selected rules, else the open rule, else the open group. Always asks first.
function ns.DeleteKey()
    if ns.MultiCount() > 0 then ns.MultiDelete(); return true end
    local rule = SelectedRule()
    if rule and ns.IsEditLocked(rule) then   -- audit D44: a locked rule is not deleted
        ns.Print("'" .. tostring(rule.name) .. "' is edit-locked: unlock it in the sidebar to delete it.")
        return true
    end
    if rule then
        AskConfirm("Delete the rule '" .. tostring(rule.name) .. "'? " .. ns.RecycleBinNote(), function()
            ns.RecycleRule(rule)
            ns.MarkDirty(); Notify(); SelectRoot()
        end)
        return true
    end
    local g = ns.SelectedGroup()
    if g and ns.IsEditLocked({ folder = g.id }) then
        ns.Print("the group '" .. tostring(g.name) .. "' is edit-locked: unlock it in the sidebar to delete it.")
        return true
    end
    if g then
        AskConfirm("Delete the group '" .. tostring(g.name) .. "'? Its rules and nested groups are kept and move up one level. " .. ns.RecycleBinNote(), function() ns.DeleteFolderById(g.id) end)
        return true
    end
    return false
end

-------------------------------------------------------------------------------
-- Window chrome: a close X (top right) and a collapse arrow (shrinks the window to
-- just the XayaUI banner). Collapse state is session-only and resets when the window closes.
-------------------------------------------------------------------------------

-- for the other files of this folder (ns.OptionsApi.RuleEditorParts)
P.SelectedRule = SelectedRule
-- for Options.lua (ns.OptionsApi.RuleEditor): the rule selected in the Rules sidebar (the debug console strip shows its status)
ns.OptionsApi.RuleEditor.SelectedRule = SelectedRule
