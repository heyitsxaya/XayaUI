-------------------------------------------------------------------------------
-- XayaUI_Options/Mover.lua : the mover (/xui unlock and the Lock Positions buttons): dragging, nudging and anchoring XayaUI's displays
-- and groups on screen, its draft with Save / Cancel, and everything it shows (group tags and outlines, the group X / Y box, the frame
-- picker, the display menu) plus the settings window's other on-screen unlocks (a rule's or a group's movement lock on the sidebar).
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58, her words: "mover view only available when settings window is open"; V34) Moved out of
-- XayaUI_Rules/Visual.lua into XayaUI Options, the load-on-demand settings addon: the game reads it only when the settings window's
-- code loads, never at login. The mover works only while the settings window is open, and closing the window closes it (V28). Its
-- unsaved moves follow her answer for the mover (SD-15, "Keep, resume after"): they stay on screen and in the draft, and the mover
-- opens again with them the next time the settings window opens (after combat: when the window reopens by itself). (SD-64, option 1)
-- /xui unlock opens the settings window with the mover on (XayaUI/Core.lua; in combat: one line, and it opens when combat ends).
-- What stays in XayaUI Rules is layout: the saved positions and anchors, the displays themselves, and the state the displays read
-- (ns.unlocked, ns.moveUnlocked, ns.groupUnlocked: which displays show as draggable samples). This file writes that state; Rules
-- reaches this file only through ns.MoverDisplay (a display's mouse and its mover look), and this file reaches Rules' layout through
-- ns.VisualPos (Visual.lua, at its end).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)

-- The settings window is open (told by Options.lua: Tree.DriverStart / Tree.Closed). Kept here with XayaUI Rules on or off: the
-- window's own code asks it either way.
local windowOpen = false
local WindowOpened   -- (below: what the mover does when the window opens; nil while XayaUI Rules is off)
function ns.SetWindowOpen(on)
    local was = windowOpen
    windowOpen = on and true or false
    if windowOpen and not was and WindowOpened then pcall(WindowOpened) end
end
function ns.WindowOpen() return windowOpen end
-- Closing the settings window ends everything it started on screen (core 0.6.56; Xaya, 2026-11-06: "typing /xui and closing the menu
-- does not turn off previews -- this is a high priority issue, as it indicates that the addon is still running its options pane
-- indirectly in some way. this should not happen"). Previews, the preview pause, the sidebar's per-rule and per-group movement unlocks
-- (sample displays with their boxes and names), and (SD-58) the mover with its X / Y box and frame picker.
local WindowClosed   -- (below; nil while XayaUI Rules is off)
function ns.EndWindowState()
    if ns.ClearPreview and ns.AnyPreview and ns.AnyPreview() then ns.ClearPreview() end
    if ns.previewPaused and ns.SetPreviewPaused then ns.SetPreviewPaused(false) end
    if WindowClosed then WindowClosed() end
    if ns.MarkDirty then ns.MarkDirty() end
end

-- With XayaUI Rules switched off there are no displays to move: nothing below is made.
if not (ns.OptionsApi and ns.Service and ns.Service("rules") and ns.VisualPos) then return end

local CoreS = ns.Settings("core")
local VP = ns.VisualPos
local frames = VP.frames   -- rule -> its display frame (Visual.lua's own table)
local InFolder, GroupBounds, GroupScreenBounds, ScreenRect = VP.InFolder, VP.GroupBounds, VP.GroupScreenBounds, VP.ScreenRect
local GroupTargetScale, GroupPosChanged, CenterGroup, ParentFor = VP.GroupTargetScale, VP.GroupPosChanged, VP.CenterGroup, VP.ParentFor
local function Unl(rule) return ns.IsMoveUnlocked(rule) end
local function InCombat() return (InCombatLockdown and InCombatLockdown()) and true or false end
-- the game's aura containers step aside for the samples and back (XayaUI_Rules/Combat/AuraDisplay.lua). Its hooks on Rules' four mover
-- names (ns.ToggleUnlock, ns.MoverExit, ns.SetMoveUnlocked, ns.SetGroupUnlocked) follow those; the mover's other changes (opening again
-- with the window, closing with it or at combat start, /xui disable) tell it here.
local function SyncEngine()
    if ns.AuraDisplay and ns.AuraDisplay.SyncLive then pcall(ns.AuraDisplay.SyncLive) end
end
local mover = { tempLock = {}, sel = nil, picking = nil }
-- the mover's handlers, published to XayaUI Rules' seam (ns.MoverDisplay, Visual.lua) at the end of this file; Rules' ns.ToggleUnlock,
-- ns.MoverExit, ns.SetMoveUnlocked and ns.SetGroupUnlocked forward to them (the combat engine hooks those names: it follows each change)
local M = {}

-------------------------------------------------------------------------------
-- (V26) The context menus XayaUI opens: the display menu below (its entries are also the rows of the element menu, ElementMenu.lua)
-- and the settings window's sidebar menus (RuleEditor/Sidebar.lua: a row's menu, the blank-space menu, Move Selected To).
-- The game's menu can stay on screen after the window or the mover it came from has closed, and into a fight. Every choice in
-- these menus goes through MenuChoice: in combat it changes nothing and prints one line; once its window or mover has closed it
-- changes nothing. Reading what is ticked (a radio's or check box's state) is not gated: it changes nothing.
-- The menus open on XayaUI's own owner frame (ns.ContextMenuOwner), which is hidden when combat starts (PLAYER_REGEN_DISABLED, an event
-- registered only while the owner is shown) and when its window or mover closes (MenuOwnerCheck). UNVERIFIED IN GAME: whether
-- the game's menu closes with its owner; if it stays up, its choices still change nothing.
-------------------------------------------------------------------------------
local MENU_COMBAT = "menus can't be used during combat, so nothing was changed."
local function MenuChoice(isOpen, fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        if InCombat() then ns.Print(MENU_COMBAT); return end
        if isOpen and not isOpen() then return end
        return fn(...)
    end
end
ns.MenuChoice = MenuChoice
-- A menu description whose choices all go through MenuChoice: CreateButton(text, choice, ...), CreateCheckbox / CreateRadio(text,
-- isSelected, choice, ...); a submenu made from it is guarded the same way; every other call goes straight to the description. Built
-- when a menu opens, never while it is shown.
local function GuardMenu(desc, isOpen)
    if type(desc) ~= "table" then return desc end
    return setmetatable({}, { __index = function(_, k)
        local v = desc[k]
        if type(v) ~= "function" then return v end
        if k == "CreateButton" then
            return function(_, text, fn, ...) return GuardMenu(v(desc, text, MenuChoice(isOpen, fn), ...), isOpen) end
        elseif k == "CreateCheckbox" or k == "CreateRadio" then
            return function(_, text, isSel, fn, ...) return GuardMenu(v(desc, text, isSel, MenuChoice(isOpen, fn), ...), isOpen) end
        end
        return function(_, ...) return v(desc, ...) end
    end })
end
ns.GuardMenu = GuardMenu
-- One owner frame for every context menu XayaUI opens (the game keeps one context menu open at a time), laid over the clicked region;
-- it draws nothing and takes no mouse. strata: "TOOLTIP" raises the game's menu above the settings window (Sidebar.lua).
local menuOwner, menuOwnerOpen
function ns.ContextMenuOwner(region, strata, isOpen)
    if not menuOwner then
        menuOwner = CreateFrame("Frame", nil, UIParent)
        menuOwner:EnableMouse(false)
        menuOwner:SetScript("OnEvent", function(self) self:Hide() end)   -- PLAYER_REGEN_DISABLED: combat starts
        menuOwner:SetScript("OnHide", function(self) self:UnregisterEvent("PLAYER_REGEN_DISABLED"); menuOwnerOpen = nil end)
    end
    menuOwner:SetFrameStrata(strata or "HIGH")
    menuOwner:ClearAllPoints()
    menuOwner:SetPoint("TOPLEFT", region, "TOPLEFT")
    menuOwner:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")
    menuOwnerOpen = isOpen
    menuOwner:Show()
    menuOwner:RegisterEvent("PLAYER_REGEN_DISABLED")
    return menuOwner
end
function ns.ContextMenuOwnerShown() return menuOwner ~= nil and menuOwner:IsShown() end   -- (tests)
-- the window or mover the open menu came from has closed: its owner goes too
local function MenuOwnerCheck()
    if menuOwner and menuOwner:IsShown() and not (menuOwnerOpen and menuOwnerOpen()) then menuOwner:Hide() end
end

-------------------------------------------------------------------------------
-- On-screen selection and drag snapping (only while displays are unlocked)
-------------------------------------------------------------------------------
ns.selectedVisual = nil
local SNAP_GRID, SNAP_NEAR = 10, 10
local SNAP_LABELS = { free = "Free Move", grid = "Grid (10 px)", auras = "Other Auras' Edges & Centers", center = "Screen Center Lines" }
-- border color for an unlocked display: white while hovered (this is the box a click will hit), orange when
-- selected, cyan otherwise. A faint white wash on hover makes it readable over busy art.
local function PaintBorder(r, f)
    if not (Unl(r) and f.SetBackdropBorderColor) then return end
    if f.hovered then f:SetBackdropBorderColor(1, 1, 1, 1)
    elseif r == ns.selectedVisual then f:SetBackdropBorderColor(1, 0.6, 0.1, 1)
    else f:SetBackdropBorderColor(0.2, 0.8, 1, 1) end
    if f.hoverTex then f.hoverTex:SetShown(f.hovered and true or false) end
end
local function PaintBorders()
    for r, f in pairs(frames) do PaintBorder(r, f) end
end
function ns.SelectVisual(rule) ns.selectedVisual = rule; PaintBorders() end
local function SnapMode() return CoreS.snapMode or "free" end   -- (P5: XayaUI Rules' store; CueRulesDB.ui.snapMode before)
-- x, y are offsets of the frame center from the screen center (UI units). Returns the snapped offsets.
function ns.SnapPosition(rule, fr, x, y)
    local mode = SnapMode()
    if mode == "grid" then
        return math.floor(x / SNAP_GRID + 0.5) * SNAP_GRID, math.floor(y / SNAP_GRID + 0.5) * SNAP_GRID
    elseif mode == "center" then
        if math.abs(x) <= SNAP_NEAR then x = 0 end
        if math.abs(y) <= SNAP_NEAR then y = 0 end
        return x, y
    elseif mode == "auras" then
        local ux, uy = UIParent:GetCenter()
        local w, h = fr:GetWidth() / 2, fr:GetHeight() / 2
        local bestX, bestY, dX, dY = nil, nil, SNAP_NEAR + 1, SNAP_NEAR + 1
        for r, o in pairs(frames) do
            if r ~= rule and o:IsShown() and o:GetCenter() then
                local s = o:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local ocx, ocy = o:GetCenter()
                ocx, ocy = ocx * s - ux, ocy * s - uy
                local ow, oh = o:GetWidth() * s / 2, o:GetHeight() * s / 2
                -- my left / center / right against their left / center / right (and the same vertically)
                for _, mine in ipairs({ -w, 0, w }) do
                    for _, theirs in ipairs({ ocx - ow, ocx, ocx + ow }) do
                        local d = math.abs((x + mine) - theirs)
                        if d < dX then dX = d; bestX = theirs - mine end
                    end
                end
                for _, mine in ipairs({ -h, 0, h }) do
                    for _, theirs in ipairs({ ocy - oh, ocy, ocy + oh }) do
                        local d = math.abs((y + mine) - theirs)
                        if d < dY then dY = d; bestY = theirs - mine end
                    end
                end
            end
        end
        if bestX and dX <= SNAP_NEAR then x = math.floor(bestX + 0.5) end
        if bestY and dY <= SNAP_NEAR then y = math.floor(bestY + 0.5) end
    end
    return x, y
end

-------------------------------------------------------------------------------
-- Paired auras (session only): dragging one drags the other with it. Pairing unlocks the partner for movement, and
-- locking (or unpairing) puts that back.
-------------------------------------------------------------------------------
local pairOf, tempUnl = {}, {}   -- session-only paired-aura links (both directions) and the auras a pair unlocked for its partner
function ns.PairedWith(rule) return pairOf[rule] end
function ns.ClearPair(rule)
    local o = pairOf[rule]
    if not o then return end
    pairOf[rule], pairOf[o] = nil, nil
    for _, r in ipairs({ rule, o }) do
        if tempUnl[r] then tempUnl[r] = nil; ns.SetMoveUnlocked({ r }, false) end
    end
end
function ns.SetPair(rule, other)
    ns.ClearPair(rule)
    if not other or other == rule then return end
    ns.ClearPair(other)
    pairOf[rule], pairOf[other] = other, rule
    for _, r in ipairs({ rule, other }) do
        if not Unl(r) then tempUnl[r] = true; ns.SetMoveUnlocked({ r }, true) end
    end
end
-- Linked auras (saved on the rule as rule.link = a shared id): dragging any member moves every other member by the same amount, so
-- their positions relative to each other are kept. Hold SHIFT when you start a drag to move just that one (its offset to the others
-- then changes, which is the new relative position). Members that are snapped to a game frame are left where they are.
function ns.LinkMembers(rule)
    local out = {}
    local id = rule and rule.link
    if not id then return out end
    for _, o in ipairs(ns.rules or {}) do if o ~= rule and o.link == id and o.visual then out[#out + 1] = o end end
    return out
end
function ns.LinkAura(rule, other)
    if not (rule and other and rule ~= other) then return end
    local id = other.link or rule.link or ("L" .. tostring(time()) .. tostring(math.random(1000, 9999)))
    -- joining another group moves the whole of the old group's membership with the dragged rule's choice: keep it simple, only this rule joins
    other.link, rule.link = id, id
    if ns.MarkDirty then ns.MarkDirty() end
end
function ns.UnlinkAura(rule)
    if not (rule and rule.link) then return end
    local id = rule.link
    rule.link = nil
    local left, last = 0, nil
    for _, o in ipairs(ns.rules or {}) do if o.link == id then left = left + 1; last = o end end
    if left == 1 then last.link = nil end   -- a link of one is no link
    if ns.MarkDirty then ns.MarkDirty() end
end
-- (round 7 repair, V28) a drag still running on a display that locks (its sidebar lock, the mover closing, the window closing, combat,
-- /xui disable) is dropped here: the display stops following the cursor and goes back to its last place (the caller's refresh), and the
-- displays riding along go back too. A locked display forwards no mouse to this file (Visual.lua), so its drag must end before it locks.
local function DropDrag(fr)
    if not (fr and fr.dragFrom) then return end
    pcall(fr.StopMovingOrSizing, fr)
    local rides, pr = fr.linkRides, fr.pairRule
    fr.dragFrom, fr.wasDragged, fr.linkRides, fr.linkHidden, fr.linkStart, fr.pairRule, fr.pairFr = nil, false, nil, nil, nil, nil, nil
    for _, p in ipairs(rides or {}) do pcall(ns.RefreshVisual, p[1]) end
    if pr then pcall(ns.RefreshVisual, pr) end
end
local function DropAllDrags() for _, fr in pairs(frames) do DropDrag(fr) end end
-- a rule's own movement unlock (the lock icon on its sidebar row; also a paired aura's partner). (SD-58, V28) Only while the settings
-- window is open; locking again always works (the window's closing does it).
function M.SetMoveUnlocked(objs, on)
    if on and not windowOpen then return end
    for _, r in ipairs(objs or {}) do
        if not on and not ns.unlocked then DropDrag(frames[r]) end   -- (with the whole mover still on, the display stays draggable)
        if not on and pairOf[r] then ns.ClearPair(r) end
        ns.moveUnlocked[r] = on and true or nil
        if r.visual then
            ns.RefreshVisual(r)
            ns.SetVisualShown(r, ns.runtime and ns.runtime[r] and ns.runtime[r].visualWanted)
        end
    end
end

-------------------------------------------------------------------------------
-- Anchor to any frame on screen (Xaya 2026-11-04, on the group X / Y popup: "allow anchoring/snapping to other frames in the UI").
-- Picking: a banner asks to point at a frame and press Shift (a click would also hit the frame: target a unit, cast a spell). The
-- frame under the cursor is read with GetMouseFoci() (docs/reference/api/globals.md:214, no flags) and walked up to its first NAMED
-- parent that the name finds again (_G[name] == frame): only a name survives a /reload. Forbidden frames, UIParent / WorldFrame and
-- XayaUI's own picker frames are skipped. The candidate is outlined with its name; Cancel (or 30 s) stops. It closes with the window.
-------------------------------------------------------------------------------
local picker
local function NamedTarget(r)
    local guard = 0
    while r and guard < 40 do
        guard = guard + 1
        local okF, forb = pcall(function() return r.IsForbidden and r:IsForbidden() end)
        if not okF or forb then return nil end
        if r == UIParent or r == WorldFrame or r.xuiPickerOwn then return nil end
        local okN, name = pcall(function() return r.GetName and r:GetName() end)
        if okN and type(name) == "string" and name ~= "" and not ns.IsSecret(name) and _G[name] == r and r.GetRect then return r, name end
        local okP, par = pcall(function() return r.GetParent and r:GetParent() end)
        r = okP and par or nil
    end
end
function ns.FrameUnderCursor()
    if type(GetMouseFoci) ~= "function" then return nil end
    local ok, foci = pcall(GetMouseFoci)
    if not (ok and type(foci) == "table") then return nil end
    for _, r in ipairs(foci) do
        local f, name = NamedTarget(r)
        if f then return f, name end
    end
end
-- B: the group (that forFo may follow) whose mover tag or outline (what it shows, 4 px out) is under the cursor; the
-- smallest one when they overlap (a nested group inside its parent). Returns { fo, l, b, r, t } (the outline to draw, screen pixels).
local function GroupUnderCursor(forFo)
    local cx, cy = GetCursorPosition()
    if not cx then return nil end
    local us = UIParent:GetEffectiveScale()
    local best, bestArea
    local function inside(l, b, r, t) return l and cx >= l and cx <= r and cy >= b and cy <= t end
    for _, g in ipairs(ns.folders or {}) do
        if ns.GroupAnchorAllowed(forFo, g) then
            local ol, ob, orr, ot = GroupScreenBounds(g)
            if ol then local pad = 4 * us; ol, ob, orr, ot = ol - pad, ob - pad, orr + pad, ot + pad end
            local hit = inside(ol, ob, orr, ot)
            local hl, hb, hr, ht
            local tag = ns.GroupTagFor and ns.GroupTagFor(g.id)
            if not hit and tag and tag:IsShown() and (tag:GetAlpha() or 0) > 0 then
                hl, hb, hr, ht = ScreenRect(tag); hit = inside(hl, hb, hr, ht)
            end
            if hit then
                local l, b, r, t = ol, ob, orr, ot
                if not l then l, b, r, t = hl, hb, hr, ht end
                local area = (r - l) * (t - b)
                if not bestArea or area < bestArea then best, bestArea = { fo = g, l = l, b = b, r = r, t = t }, area end
            end
        end
    end
    return best
end
local RefreshGroupTags   -- (below)
function ns.PickFrame(title, onPick, forGroup)
    -- (V26) never in combat (a menu left open from before the fight could ask for it): picking moves a display or a group
    if InCombat() then ns.Print("picking a frame to snap to can't be done during combat."); return nil end
    -- (SD-58, V28) only while the settings window is open: it moves a display or a group, which is the mover's and the window's work
    if not windowOpen then return nil end
    local P = picker
    if not P then
        P = CreateFrame("Frame", "XayaUIFramePicker", UIParent, "BackdropTemplate")
        P.xuiPickerOwn = true
        P:SetSize(420, 58); P:SetPoint("TOP", UIParent, "TOP", 0, -60); P:SetFrameStrata("TOOLTIP"); P:EnableMouse(true)
        P:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        P:SetBackdropColor(0.05, 0.05, 0.05, 0.95); P:SetBackdropBorderColor(1, 0.6, 0.1, 1)
        P.text = P:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); P.text:SetPoint("TOPLEFT", ns.UI_MARGIN, -ns.UI_MARGIN); P.text:SetPoint("RIGHT", -90, 0)
        P.text:SetJustifyH("LEFT")
        P.cancel = CreateFrame("Button", nil, P, "UIPanelButtonTemplate"); P.cancel:SetSize(70, 22); P.cancel:SetPoint("RIGHT", -10, 0)
        P.cancel:SetText("Cancel"); P.cancel.xuiPickerOwn = true
        P.cancel:SetScript("OnClick", function() P:Hide() end)
        if ns.FlatButton then ns.FlatButton(P.cancel) end
        P.hi = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        P.hi.xuiPickerOwn = true
        P.hi:SetFrameStrata("TOOLTIP"); P.hi:EnableMouse(false)
        P.hi:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 }); P.hi:SetBackdropBorderColor(0.3, 1, 0.3, 1)
        P.hi.label = P.hi:CreateFontString(nil, "OVERLAY", "GameFontNormal"); P.hi.label:SetPoint("BOTTOMLEFT", P.hi, "TOPLEFT", 0, 2)
        P.hi:Hide()
        P:SetScript("OnHide", function(self)
            self.hi:Hide(); self.onPick = nil
            if self.forGroup then   -- B: the mover tags shown for the picker go back to what the mover shows
                self.forGroup, self.candGroup, mover.picking = nil, nil, nil
                RefreshGroupTags()
            end
        end)
        P:SetScript("OnUpdate", function(self)
            if GetTime() - (self.startedAt or 0) > 30 then self:Hide(); return end
            local f, name, l, b, r, t
            -- B: picking for a group: another group's tag / outline / box comes first (one that may be followed: not the group
            -- itself, nothing that makes a loop), labelled with its name
            local g = self.forGroup and GroupUnderCursor(self.forGroup)
            if g then
                l, b, r, t = g.l, g.b, g.r, g.t
                name = tostring(g.fo.name)
                self.cand, self.candName, self.candGroup = nil, name, g.fo
            else
                f, name = ns.FrameUnderCursor()
                self.cand, self.candName, self.candGroup = f, name, nil
            end
            local us = UIParent:GetEffectiveScale()
            if f then l, b, r, t = ScreenRect(f) end
            if l then
                self.hi:ClearAllPoints()
                self.hi:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l / us, b / us)
                self.hi:SetSize(math.max(4, (r - l) / us), math.max(4, (t - b) / us))
                self.hi.label:SetText(name)
                self.hi:Show()
            else
                self.hi:Hide()
            end
            local down = IsShiftKeyDown and IsShiftKeyDown() or false
            if down and not self.shiftWas and (f or self.candGroup) then
                local fn, grp = self.onPick, self.candGroup
                self:Hide()
                if fn then fn(f, name, grp) end   -- (a group: frame nil, its name, the group)
                return
            end
            self.shiftWas = down
        end)
        picker = P
    end
    -- forGroup (B): the group being anchored; while the picker is open every group's mover tag shows and other groups can be picked
    P.text:SetText((title or "Anchor to a frame") .. "\n|cffaaaaaa" .. (forGroup and "Point at a frame or a group and press Shift. Cancel stops." or "Point at a frame and press Shift. Cancel stops.") .. "|r")
    P.onPick, P.startedAt, P.shiftWas = onPick, GetTime(), (IsShiftKeyDown and IsShiftKeyDown()) or false
    P.forGroup, P.candGroup = forGroup, nil
    mover.picking = forGroup
    if forGroup then RefreshGroupTags() end
    P:Show()
    return P
end
function ns.FramePicker() return picker end   -- (tests)

-------------------------------------------------------------------------------
-- Right-click on a group's outline or tag: type the group's X / Y, or center it on the screen on one axis or both ("center" = the
-- outline's middle on the screen's middle). X / Y are the same numbers as the group's X / Y offset options. It closes with the window.
-------------------------------------------------------------------------------
local posPopup
local function AnchorText(fo)
    if fo.cRel == "custom" and fo.cFrame then
        local g = _G[fo.cFrame]
        return "Anchored to |cffffd100" .. fo.cFrame .. "|r" .. ((g and g.GetRect) and "" or " |cffff6060(not found now: the screen)|r")
    end
    local tg = ns.GroupAnchorTarget(fo)
    if tg then return "Anchored to group '|cffffd100" .. tostring(tg.name) .. "|r'" end
    if fo.cRel and fo.cRel ~= "group" then return "Anchored to |cffffd100" .. tostring(fo.cRel) .. "|r" end
    return "Anchored to the screen" .. (fo.parent and " (its parent group)" or "")
end
local function FillPosPopup(p)
    local fo = ns.FolderById(p.fid)
    if not fo then p:Hide() return end
    p.title:SetText(tostring(fo.name))
    if p.anchorText then p.anchorText:SetText(AnchorText(fo)) end
    if p.flush then p.flush:SetEnabled((fo.cRel == "custom" and fo.cFrame ~= nil) or ns.GroupAnchorTarget(fo) ~= nil) end
    p.x:SetText(tostring(fo.cX or 0)); p.y:SetText(tostring(fo.cY or 0))
    p.x:SetCursorPosition(0); p.y:SetCursorPosition(0)
end
local function ShowGroupPosPopup(fo)
    if not windowOpen then return end   -- (SD-58, V28) only while the settings window is open
    local p = posPopup
    if not p then
        p = CreateFrame("Frame", "XayaUIGroupPosPopup", UIParent, "BackdropTemplate")
        -- rows from the top, G apart (#351 phase 2; they were 4-8 px apart and the last one 8 px from the bottom); the height is set
        -- after the last row
        local M, G = ns.UI_MARGIN, ns.UI_GUTTER
        p:SetSize(260, 384); p:SetFrameStrata("FULLSCREEN_DIALOG"); p:SetClampedToScreen(true); p:EnableMouse(true)
        -- (Xaya 2026-11-08, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #11-#12: "I need to be able to move the rule box around so that
        -- I can actually see what I'm working on"): the box drags by any part that is not a button or a number box. It is never a
        -- frame "Anchor to a frame on screen..." can pick (the group was anchored to this box: "Anchored to XayaUIGroupPosPo...").
        p:SetMovable(true); p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart", function(self) self:StartMoving() end)
        p:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        p.xuiPickerOwn = true
        p:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        p:SetBackdropColor(0.05, 0.05, 0.05, 0.96); p:SetBackdropBorderColor(1, 0.6, 0.1, 1)
        p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal"); p.title:SetPoint("TOP", 0, -M)
        local y = M + 14 + G   -- the next row's top, from the popup's top (under the 14 px title)
        local function Box(label, y)
            local fsl = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); fsl:SetPoint("TOPLEFT", 16, y); fsl:SetText(label)
            local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
            eb:SetSize(100, 20); eb:SetPoint("TOPLEFT", 110, y + 4); eb:SetAutoFocus(false); eb:SetMaxLetters(8)
            eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            if ns.KeyFocusGuard then ns.KeyFocusGuard(eb) end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
            return eb
        end
        local function Apply()
            local fo2 = ns.FolderById(p.fid)
            if not fo2 then return end
            local x, y = tonumber(p.x:GetText()), tonumber(p.y:GetText())
            if x then fo2.cX = math.floor(x + 0.5) end
            if y then fo2.cY = math.floor(y + 0.5) end
            GroupPosChanged(fo2); FillPosPopup(p)
        end
        p.x = Box("X offset", -(y + 4)); y = y + 20 + G   -- Box puts the 20 px edit box 4 px above its label
        p.y = Box("Y offset", -(y + 4)); y = y + 20 + G
        p.x:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Apply() end)
        p.y:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Apply() end)
        local btns = {}
        local function Btn(text, fn)
            local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            b:SetSize(228, 22); b:SetPoint("TOP", 0, -y); b:SetText(text)
            y = y + 22 + G
            -- a button press gives the keyboard back: a number box left with focus kept the arrow keys from the mover (#13)
            b:SetScript("OnClick", function() p.x:ClearFocus(); p.y:ClearFocus(); fn() end)
            if ns.FlatButton then ns.FlatButton(b) end
            btns[#btns + 1] = b
            return b
        end
        Btn("Apply X / Y", Apply)
        Btn("Center on screen (X)", function() local f2 = ns.FolderById(p.fid); if f2 then CenterGroup(f2, true, false); FillPosPopup(p) end end)
        Btn("Center on screen (Y)", function() local f2 = ns.FolderById(p.fid); if f2 then CenterGroup(f2, false, true); FillPosPopup(p) end end)
        Btn("Center on screen (X, Y)", function() local f2 = ns.FolderById(p.fid); if f2 then CenterGroup(f2, true, true); FillPosPopup(p) end end)
        p.anchorText = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        p.anchorText:SetPoint("TOPLEFT", 16, -y); p.anchorText:SetPoint("RIGHT", -16, 0); p.anchorText:SetJustifyH("LEFT")
        p.anchorText:SetHeight(24); p.anchorText:SetJustifyV("TOP")   -- room for two lines (a long frame name)
        y = y + 24 + G
        Btn("Anchor to a frame on screen...", function()
            local f2 = ns.FolderById(p.fid); if not f2 then return end
            ns.PickFrame("Anchor the group '" .. tostring(f2.name) .. "' to a frame", function(target, name, group)
                local f3 = ns.FolderById(p.fid); if not f3 then return end
                if group then   -- B: another group
                    if ns.AnchorGroupToGroup(f3, group) then ns.Print("group '" .. tostring(f3.name) .. "' anchored to group '" .. tostring(group.name) .. "' (it stays where it is; Snap flush closes the gap)") end
                elseif ns.AnchorGroupToFrame(f3, target, name) then ns.Print("group '" .. tostring(f3.name) .. "' anchored to " .. name .. " (it stays where it is; Snap flush closes the gap)") end
                if p:IsShown() then FillPosPopup(p) end
            end, f2)
        end)
        p.flush = Btn("Snap flush to that frame", function() local f2 = ns.FolderById(p.fid); if f2 then ns.SnapGroupFlush(f2); FillPosPopup(p) end end)
        Btn("Anchor to the screen (stays in place)", function() local f2 = ns.FolderById(p.fid); if f2 then ns.UnanchorGroup(f2); FillPosPopup(p) end end)
        Btn("Close", function() p:Hide() end)
        p:SetHeight(y - G + M)   -- 384: M under the Close button
        -- every button as wide as the longest label needs (#11: "all buttons should not have text overflow"; "Anchor to the screen
        -- (stays in place)" ran past both edges of its 228 px button): the label's own width (GetUnboundedStringWidth, as Skin.lua's
        -- compact buttons measure it) plus 34 px (the template pins the label 15 px in from each side), the box 16 px wider each side
        local need = 228
        for _, b in ipairs(btns) do
            local fs = b.GetFontString and b:GetFontString()
            local ok, w = pcall(function() return fs and (fs.GetUnboundedStringWidth or fs.GetStringWidth)(fs) end)
            if ok and type(w) == "number" then need = math.max(need, math.ceil(w + 34)) end
        end
        for _, b in ipairs(btns) do b:SetWidth(need) end
        p:SetWidth(math.max(260, need + 32))
        if UISpecialFrames then table.insert(UISpecialFrames, "XayaUIGroupPosPopup") end
        posPopup = p
    end
    p.fid = fo.id
    FillPosPopup(p)
    local cx, cy = GetCursorPosition()
    local us = UIParent:GetEffectiveScale()
    p:ClearAllPoints(); p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / us + 10, cy / us - 10)
    p:Show()
end

-------------------------------------------------------------------------------
-- A group's own movement unlock (the lock icon on its sidebar row): one draggable outline fitted around the group's shown displays,
-- which drags the GROUP (its X / Y), not the displays.
-------------------------------------------------------------------------------
local groupHandles = {}
local function GroupHandle(f)
    local h = groupHandles[f.id]
    if h then return h end
    h = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    h:SetFrameStrata("HIGH"); h:SetFrameLevel(900)
    h:EnableMouse(true)
    h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    h:SetBackdropColor(1, 0.6, 0.1, 0.08); h:SetBackdropBorderColor(1, 0.6, 0.1, 1)
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.label:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 0, 2)
    h.fid = f.id
    local function Done(self)
        if not self.drag then return end
        self.drag = nil
        ns.MarkDirty()
        ns.Fire("CONFIG_CHANGED")
    end
    h:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        local fo = ns.FolderById(self.fid)
        if not fo then return end
        if not ns.IsMoverTempLocked(fo) then ns.MoverSelect("group", fo) end
        if ns.IsMoverTempLocked(fo) then return end   -- (locked for now: the tag still opens the settings, but does not drag)
        local cx, cy = GetCursorPosition()
        self.drag = { cx = cx, cy = cy, x = fo.cX or 0, y = fo.cY or 0 }
    end)
    h:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" then
            local fo = ns.FolderById(self.fid)
            if fo then ShowGroupPosPopup(fo) end
        else
            Done(self)
        end
    end)
    h:SetScript("OnUpdate", function(self)
        local fo = ns.FolderById(self.fid)
        if not fo or not ns.groupUnlocked[self.fid] then self:Hide() return end
        if self.drag then
            if not IsMouseButtonDown("LeftButton") then Done(self)
            else
                local ts = GroupTargetScale(fo)
                local cx, cy = GetCursorPosition()
                fo.cX = math.floor(self.drag.x + (cx - self.drag.cx) / ts + 0.5)
                fo.cY = math.floor(self.drag.y + (cy - self.drag.cy) / ts + 0.5)
                ns.GroupFrame(fo)
            end
        end
        local l, b, r, t = GroupBounds(fo)
        self:ClearAllPoints()
        if l then
            local pad = 4
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - pad, b - pad)
            self:SetSize(math.max(24, r - l + 2 * pad), math.max(24, t - b + 2 * pad))
        else   -- nothing visible inside: a small box at the group's own position (fix A: its anchor point, not the container's centre)
            local cx, cy = ns.GroupAnchorXY(fo)
            if cx then self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy) else self:SetPoint("CENTER") end
            self:SetSize(80, 40)
        end
    end)
    groupHandles[f.id] = h
    return h
end
function M.SetGroupUnlocked(f, on)
    if not f or (on and not windowOpen) then return end   -- (SD-58, V28) unlocking only while the settings window is open
    ns.groupUnlocked[f.id] = on and true or nil
    local h = GroupHandle(f)
    if on then h.label:SetText(tostring(f.name) .. "  (drag to move the group; right-click for X / Y and centering)"); h:Show()
    else h.drag = nil; h:Hide(); if posPopup and posPopup.fid == f.id then posPopup:Hide() end end
    for _, r in ipairs(ns.rules or {}) do
        if r.visual and InFolder(r.folder, f.id) then
            ns.RefreshVisual(r)
            ns.SetVisualShown(r, ns.runtime and ns.runtime[r] and ns.runtime[r].visualWanted)
        end
    end
    RefreshGroupTags()   -- an unlocked group shows its handle instead of its mover tag
end

-------------------------------------------------------------------------------
-- Mover tags (Xaya 2026-11-04: "when you open the anchors/mover view, enable hover-over groups or individual icons and enable the
-- ability to go to a specific element to modify its options"). While every display is unlocked (/xui unlock), each group with a
-- display on screen gets a faint outline (it takes no mouse, so the displays inside stay draggable) and a name tab above it. Hovering
-- the tab lights the outline and names the group; a click opens the group's settings, a right-click its X / Y popup, and dragging the
-- tab moves the whole group. Nested groups stack their tabs upward so they do not cover each other. Displays get a tooltip (below).
-------------------------------------------------------------------------------
local groupTags = {}
local TAG_H, TAG_PAD = 16, 4
function ns.FolderPathText(fid)
    local names, id, g = {}, fid, 0
    while id and g < 32 do
        local f = ns.FolderById(id)
        if not f then break end
        table.insert(names, 1, tostring(f.name)); id, g = f.parent, g + 1
    end
    return table.concat(names, " > ")
end
local function FolderDepth(f)
    local d, id = 0, f.parent
    while id and d < 32 do local p = ns.FolderById(id); if not p then break end; d, id = d + 1, p.parent end
    return d
end
local function ShownIn(f)
    local n = 0
    for rule, fr in pairs(frames) do if fr:IsShown() and InFolder(rule.folder, f.id) then n = n + 1 end end
    return n
end
local function TagWanted(f)
    -- (B: also while the frame picker is open for a group: "every group's mover tag shows while the picker is open")
    return (ns.unlocked or mover.picking ~= nil) and f and f.default ~= "cursor" and not ns.groupUnlocked[f.id]   -- (an unlocked group has its own handle)
end
local function TagTooltip(t)
    local fo = ns.FolderById(t.fid)
    if not (fo and GameTooltip) then return end
    ns.Tip.Show(t, "ANCHOR_TOP", { "Group: " .. ns.FolderPathText(fo.id), 1, 0.82, 0, add = true }, {
        { ShownIn(fo) .. " display(s) on screen", 1, 1, 1 },
        { "Click: open this group's settings", 0.6, 0.85, 1 },
        { "Right-click: X / Y, centering and anchoring", 0.6, 0.85, 1 },
        { "Drag this tab: move the whole group", 0.6, 0.85, 1 } })
end
local function GroupTag(f)
    local t = groupTags[f.id]
    if t then return t end
    t = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    t:SetFrameStrata("MEDIUM"); t:SetFrameLevel(50)   -- under the displays (HIGH) and the settings window
    t:EnableMouse(true)
    t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    t:SetBackdropColor(0.05, 0.05, 0.05, 0.85); t:SetBackdropBorderColor(1, 0.6, 0.1, 0.9)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.label:SetPoint("LEFT", 4, 0)
    t.box = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    t.box:SetFrameStrata("MEDIUM"); t.box:SetFrameLevel(49)
    t.box:EnableMouse(false)
    t.box:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    t.box:SetBackdropBorderColor(1, 0.6, 0.1, 0.35)
    t.fid = f.id
    -- P5: the lock icon locks this group for now (no save): its displays let the mouse through to what is under them
    t.lock = CreateFrame("Button", nil, t)
    t.lock:SetSize(TAG_H - 2, TAG_H - 2); t.lock:SetPoint("RIGHT", -2, 0)
    t.lock.tex = t.lock:CreateTexture(nil, "OVERLAY"); t.lock.tex:SetAllPoints()
    t.lock.tex:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    t.lock:SetScript("OnClick", function()
        local fo = ns.FolderById(t.fid)
        if fo then ns.SetMoverTempLock(fo, not ns.IsMoverTempLocked(fo)) end
    end)
    t.lock:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        ns.Tip.Show(self, "ANCHOR_TOP", { ns.IsMoverTempLocked(ns.FolderById(t.fid)) and "Unlock this group" or "Lock this group for now", 1, 0.82, 0, add = true },
            { { "While locked its displays cannot be dragged and the mouse reaches what is under them. Nothing is saved; it ends when you leave the mover view.", 1, 1, 1, true } })
    end)
    t.lock:SetScript("OnLeave", function() ns.Tip.Hide() end)
    local function Lit(on) t.box:SetBackdropBorderColor(1, 0.6, 0.1, on and 1 or 0.35) end
    t:SetScript("OnEnter", function(self) self.hovered = true; Lit(true); TagTooltip(self) end)
    t:SetScript("OnLeave", function(self)
        self.hovered = false; Lit(false)
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end)
    t:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" then return end
        local fo = ns.FolderById(self.fid)
        if not fo then return end
        -- audit D27 (core 0.6.67): like the sidebar handle: a click selects the group for arrow-key nudges (QA B178), and a group
        -- locked for now does not drag ("its tag does not drag"); the click still opens its settings (OnMouseUp)
        if not ns.IsMoverTempLocked(fo) then ns.MoverSelect("group", fo) end
        if ns.IsMoverTempLocked(fo) then self.drag = { locked = true }; return end
        local cx, cy = GetCursorPosition()
        self.drag = { cx = cx, cy = cy, x = fo.cX or 0, y = fo.cY or 0, moved = false }
    end)
    t:SetScript("OnMouseUp", function(self, btn)
        local fo = ns.FolderById(self.fid)
        if not fo then self.drag = nil; return end
        if btn == "RightButton" then
            self.drag = nil
            -- (#13, Xaya 2026-11-08: "in mover mode, I can't use arrow keys"): the group whose X / Y box is open is the one the arrow
            -- keys nudge, as a left-click selects it
            if not ns.IsMoverTempLocked(fo) then ns.MoverSelect("group", fo) end
            ShowGroupPosPopup(fo); return
        end
        local d = self.drag
        self.drag = nil
        if d and d.moved then GroupPosChanged(fo)   -- a drag: the new X / Y is saved
        elseif ns.EditFolder then ns.EditFolder(fo) end   -- a click: open the group's settings
    end)
    t:SetScript("OnUpdate", function(self)
        local fo = ns.FolderById(self.fid)
        if not TagWanted(fo) then self.drag = nil; self:Hide(); self.box:Hide(); return end
        local d = self.drag
        if d and d.locked then
            if not IsMouseButtonDown("LeftButton") then self.drag = nil end
        elseif d then
            if not IsMouseButtonDown("LeftButton") then
                self.drag = nil
                if d.moved then GroupPosChanged(fo) end
            else
                local cx, cy = GetCursorPosition()
                if d.moved or math.abs(cx - d.cx) + math.abs(cy - d.cy) > 3 then
                    d.moved = true
                    local ts = GroupTargetScale(fo)
                    fo.cX = math.floor(d.x + (cx - d.cx) / ts + 0.5)
                    fo.cY = math.floor(d.y + (cy - d.cy) / ts + 0.5)
                    ns.GroupFrame(fo)
                end
            end
        end
        local l, b, r, top = GroupBounds(fo)
        if not l then   -- nothing of this group on screen: the tag stays, invisible and not clickable, until something shows
            self:SetAlpha(0); self:EnableMouse(false); self.box:Hide()
            return
        end
        self:SetAlpha(1); self:EnableMouse(true)
        local locked = ns.IsMoverTempLocked(fo)
        self.label:SetText(tostring(fo.name) .. (locked and " (locked)" or ""))
        self.lock.tex:SetDesaturated(not locked); self.lock.tex:SetAlpha(locked and 1 or 0.6)
        self:SetSize(math.max(40, (self.label:GetStringWidth() or 40) + 8 + TAG_H), TAG_H)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - TAG_PAD, top + TAG_PAD + 1 + FolderDepth(fo) * (TAG_H + 1))
        self.box:ClearAllPoints()
        self.box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l - TAG_PAD, b - TAG_PAD)
        self.box:SetSize(r - l + 2 * TAG_PAD, top - b + 2 * TAG_PAD)
        self.box:Show()
    end)
    t:Hide(); t.box:Hide()
    groupTags[f.id] = t
    return t
end
-- shows a tag for every group while everything is unlocked (its OnUpdate keeps it in place and hides it once that ends)
RefreshGroupTags = function()
    if not (ns.unlocked or mover.picking ~= nil) then
        for _, t in pairs(groupTags) do t.drag = nil; t:Hide(); t.box:Hide() end
        return
    end
    for _, f in ipairs(ns.folders or {}) do
        if TagWanted(f) then GroupTag(f):Show() elseif groupTags[f.id] then groupTags[f.id]:Hide(); groupTags[f.id].box:Hide() end
    end
end
ns.RefreshGroupTags = RefreshGroupTags
function ns.GroupTagFor(fid) return groupTags[fid] end   -- (tests)

-------------------------------------------------------------------------------
-- The display menu (right-click on a display in the mover; its entries are also the rows of the element menu, ElementMenu.lua, which
-- takes the right-click while the window is shown): { title = text } | { divider = true } | { text, func } | { text, sub =
-- fn(menuDescription) } | { radio = text, checked = fn, func }. (V26) Every func and every choice a sub builds goes through MenuChoice.
-------------------------------------------------------------------------------
local SNAP_POS = {
    { "TOP_LEFT", "Top Left" }, { "TOP_CENTER", "Top Center" }, { "TOP_RIGHT", "Top Right" },
    { "RIGHT_TOP", "Right Top" }, { "RIGHT_CENTER", "Right Center" }, { "RIGHT_BOTTOM", "Right Bottom" },
    { "BOTTOM_RIGHT", "Bottom Right" }, { "BOTTOM_CENTER", "Bottom Center" }, { "BOTTOM_LEFT", "Bottom Left" },
    { "LEFT_BOTTOM", "Left Bottom" }, { "LEFT_CENTER", "Left Center" }, { "LEFT_TOP", "Left Top" },
}
-- the display menu belongs to the mover (or this display's own unlock) or to the element menu: both live only while the settings
-- window is open (before round 7: the mover's unlock or the window)
local function VisualMenuOpen() return windowOpen end
local function VisualMenuParts(rule)
    local v = rule.visual
    local parts = {}
    local function add(p) parts[#parts + 1] = p end
    add({ title = rule.name or "Aura" })
    add({ text = "Snap Target", sub = function(st)
        st:CreateRadio("None (free position)", function() return not (v.snap and v.snap.target) end, function() ns.SnapToTarget(rule, nil) end)
        st:CreateButton("Pick a frame on screen...", function()
            ns.PickFrame("Snap '" .. tostring(rule.name) .. "' to a frame", function(target, name)
                local ok, pos = ns.SnapToPicked(rule, target, name)
                if ok then ns.Print("'" .. tostring(rule.name) .. "' snapped to " .. name .. " (" .. tostring(pos):lower():gsub("_", " ") .. ")") end
            end)
        end)
        if v.snap and v.snap.target == "custom" and v.snap.frame then
            st:CreateRadio("Picked: " .. tostring(v.snap.frame), function() return v.snap and v.snap.target == "custom" end, function() end)
        end
        for _, t in ipairs(VP.SnapTargets) do
            local sub = st:CreateButton(t.label)
            for _, p in ipairs(SNAP_POS) do
                sub:CreateRadio(p[2], function() return (v.snap and v.snap.target == t.key and v.snap.pos == p[1]) and true or false end,
                    function() ns.SnapToTarget(rule, t.key, p[1]) end)
            end
        end
    end })
    add({ text = "Linked Auras (move together)", sub = function(lk)
        if lk.SetScrollMode then lk:SetScrollMode(320) end
        lk:CreateRadio("Not linked", function() return not rule.link end, function() ns.UnlinkAura(rule) end)
        for _, o in ipairs(ns.rules or {}) do
            if o ~= rule and o.visual then
                lk:CreateRadio(o.name or "Aura", function() return rule.link ~= nil and o.link == rule.link end,
                    function() if rule.link and o.link == rule.link then ns.UnlinkAura(rule) else ns.LinkAura(rule, o) end end)
            end
        end
    end })
    add({ text = "Center Vertically", func = function() ns.CenterVisual(rule, "v") end })
    add({ text = "Center Horizontally", func = function() ns.CenterVisual(rule, "h") end })
    add({ text = "Paired Aura", sub = function(pr)
        if pr.SetScrollMode then pr:SetScrollMode(320) end
        pr:CreateRadio("None", function() return pairOf[rule] == nil end, function() ns.ClearPair(rule) end)
        for _, o in ipairs(ns.rules or {}) do
            if o ~= rule and o.visual and frames[o] then
                pr:CreateRadio(o.name or "Aura", function() return pairOf[rule] == o end, function() ns.SetPair(rule, o) end)
            end
        end
    end })
    add({ divider = true })
    local function setMode(mode) CoreS.snapMode = mode; ns.Print("aura positioning: " .. SNAP_LABELS[mode]) end
    add({ radio = SNAP_LABELS.free, checked = function() return SnapMode() == "free" end, func = function() setMode("free") end })
    add({ text = "Drag Snapping", sub = function(snap)
        for _, mode in ipairs({ "grid", "auras", "center" }) do
            snap:CreateRadio(SNAP_LABELS[mode], function() return SnapMode() == mode end, function() setMode(mode) end)
        end
    end })
    add({ divider = true })
    add({ text = "Edit This Aura", func = function() if ns.EditRule then ns.EditRule(rule) end end })
    local fo = rule.folder and ns.FolderById(rule.folder)
    if fo then add({ text = "Edit Its Group (" .. tostring(fo.name) .. ")", func = function() if ns.EditFolder then ns.EditFolder(fo) end end }) end
    local function isOpen() return VisualMenuOpen(rule) end
    for _, p in ipairs(parts) do
        if p.func then p.func = MenuChoice(isOpen, p.func) end
        if p.sub then local build = p.sub; p.sub = function(d) return build(GuardMenu(d, isOpen)) end end
    end
    return parts
end
ns.VisualMenuParts = VisualMenuParts   -- (tests; the element menu reads it through ns.MoverDisplay.MenuParts, below)
function ns.ShowVisualMenu(rule, anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then ns.Print("the menu API is not available in this client.") return end
    if InCombat() then ns.Print("menus can't be opened during combat."); return end
    if not windowOpen then return end   -- (SD-58, V28) only while the settings window is open
    local strata = anchor and anchor.GetFrameStrata and anchor:GetFrameStrata()
    MenuUtil.CreateContextMenu(ns.ContextMenuOwner(anchor, strata, function() return VisualMenuOpen(rule) end), function(_, root)
        for _, p in ipairs(VisualMenuParts(rule)) do
            if p.title then root:CreateTitle(p.title)
            elseif p.divider then root:CreateDivider()
            elseif p.radio then root:CreateRadio(p.radio, p.checked, p.func)
            elseif p.sub then p.sub(root:CreateButton(p.text))
            else root:CreateButton(p.text, p.func) end
        end
    end)
end

-------------------------------------------------------------------------------
-- A display's mouse in the mover (XayaUI_Rules/Visual.lua's display frames forward their mouse scripts here while they take the mouse,
-- which is only while the mover has them unlocked: its RefreshVisual asks ns.MoverDisplay.Paint and .TempLocked).
-- Left click (without dragging) selects the display and opens it in the editor; right click opens the move / snap / edit menu
-- (core 0.6.42; Xaya 2026-11-04: "right mouse click mover is unreliable") Drags are left-button only, so a right click is never
-- swallowed. A left release is ignored only when it ends a drag: while the drag runs (wasDragged) or within DRAG_UP_WINDOW after
-- OnDragStop. A drag released off the display (the game sends OnDragStop to the dragging frame but OnMouseUp only to the frame under
-- the cursor) must not swallow the next right click.
-------------------------------------------------------------------------------
local DRAG_UP_WINDOW = 0.3   -- seconds after OnDragStop in which a left release still belongs to the drag
-- A drag that moved the display this little (px, each axis) was a click with a shaky hand, not a move (core 0.6.43): Xaya's saved
-- displays shifted by 2-4 px after clicks in the mover (her XayaUI.lua, 2026-11-04, compared by the Dev Assist session).
local CLICK_SLOP = 5
local function SnapFn(rule, fr, x, y) return ns.SnapPosition(rule, fr, x, y) end
function M.TempLocked(rule) return ns.MoverTempLocked(rule) end
-- the mover look of an unlocked display: a 1 px border (PaintBorder), its name above it, a white wash on hover; made the first time
function M.Paint(rule, fr)
    if not fr.xuiMoverReady then
        fr.xuiMoverReady = true
        fr:SetMovable(true)
        fr:RegisterForDrag("LeftButton")
        fr.label = fr.txtHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fr.label:SetPoint("BOTTOM", fr, "TOP", 0, 2)
        fr.hoverTex = fr:CreateTexture(nil, "OVERLAY", nil, 7)
        fr.hoverTex:SetAllPoints()
        fr.hoverTex:SetColorTexture(1, 1, 1, 0.18)
        fr.hoverTex:Hide()
    end
    fr.xuiMoverLook = true
    fr:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    PaintBorder(rule, fr)
    fr.label:SetText(rule.name)
    fr.label:Show()
end
function M.Enter(rule, self)
    self.hovered = true
    PaintBorder(rule, self)
    -- mover (Xaya 2026-11-04): name what this is and what a click does
    if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local par = rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule)
        GameTooltip:AddLine(tostring(par and par.name or rule.name), 1, 0.82, 0)
        if par then GameTooltip:AddLine("A cue of this rule", 1, 1, 1) end
        if rule.folder then GameTooltip:AddLine("Group: " .. ns.FolderPathText(rule.folder), 1, 1, 1) end
        GameTooltip:AddLine("Click: open its settings", 0.6, 0.85, 1)
        GameTooltip:AddLine("Right-click: snap, link, center, edit its group", 0.6, 0.85, 1)
        GameTooltip:AddLine(rule.link and "Drag: move it with its linked auras (Shift: alone)" or "Drag: move it", 0.6, 0.85, 1)
        GameTooltip:Show()
    end
end
function M.Leave(rule, self)
    self.hovered = false
    PaintBorder(rule, self)
end
function M.DragStart(rule, self)
    if not Unl(rule) or ns.MoverTempLocked(rule) then return end
    ns.MoverSelect("display", rule)   -- (P4: the arrow keys nudge what was last dragged or clicked)
    self.wasDragged, self.dragStoppedAt = true, nil
    -- a paired aura rides along: anchor it to this one at its current offset for the length of the drag
    local o = pairOf[rule]
    local of = o and frames[o]
    self.pairRule, self.pairFr = nil, nil
    if of and of:IsShown() and Unl(o) then
        local ax, ay = self:GetCenter()
        local bx, by = of:GetCenter()
        if ax and bx then
            local sA, sB = self:GetEffectiveScale(), of:GetEffectiveScale()
            of:ClearAllPoints()
            of:SetPoint("CENTER", self, "CENTER", (bx * sB - ax * sA) / sB, (by * sB - ay * sA) / sB)
            self.pairRule, self.pairFr = o, of
        end
    end
    -- linked auras ride along unless SHIFT is held: shown ones are anchored to this frame at their current offset for the drag
    self.linkRides, self.linkHidden, self.linkStart = nil, nil, nil
    if rule.link and not IsShiftKeyDown() then
        local sv = rule.visual
        local pA = ParentFor(rule)
        if not (sv.snap and sv.snap.target) then self.linkStart = { sv.x or 0, sv.y or 0, pA } end
        local ax, ay = self:GetCenter()
        for _, o2 in ipairs(ns.LinkMembers(rule)) do
            local ov = o2.visual
            if not (ov.snap and ov.snap.target) then
                local of2 = frames[o2]
                if of2 and of2:IsShown() and ax then
                    local bx, by = of2:GetCenter()
                    if bx then
                        local sA, sB = self:GetEffectiveScale(), of2:GetEffectiveScale()
                        of2:ClearAllPoints()
                        of2:SetPoint("CENTER", self, "CENTER", (bx * sB - ax * sA) / sB, (by * sB - ay * sA) / sB)
                        self.linkRides = self.linkRides or {}
                        self.linkRides[#self.linkRides + 1] = { o2, of2 }
                    end
                elseif self.linkStart then
                    self.linkHidden = self.linkHidden or {}
                    self.linkHidden[#self.linkHidden + 1] = o2   -- not on screen right now: shifted by the same amount in its saved X / Y
                end
            end
        end
    end
    self.dragFrom = { self:GetCenter() }   -- where it was, to tell a small slip from a move (CLICK_SLOP)
    self:StartMoving()
end
function M.MouseUp(rule, self, button)
    if not Unl(rule) then return end
    if button == "LeftButton" and (self.wasDragged or (self.dragStoppedAt and (GetTime() - self.dragStoppedAt) <= DRAG_UP_WINDOW)) then
        self.dragStoppedAt = nil
        return
    end
    if button == "LeftButton" then
        ns.SelectVisual(rule)
        ns.MoverSelect("display", rule)
        if ns.EditRule then ns.EditRule(rule) end
    elseif button == "RightButton" then
        ns.SelectVisual(rule)
        ns.ShowVisualMenu(rule, self)
    end
end
function M.DragStop(rule, self)
    self.wasDragged, self.dragStoppedAt = false, GetTime()
    self:StopMovingOrSizing()
    local from = self.dragFrom
    self.dragFrom = nil
    local cx, cy = self:GetCenter()
    if from and from[1] and cx and math.abs(cx - from[1]) <= CLICK_SLOP and math.abs(cy - from[2]) <= CLICK_SLOP then
        -- a click, not a move: everything goes back where it is saved (nothing is saved, no snap is cleared), then the click runs
        -- (the left release that follows, or came first, is swallowed as part of the drag: one click action)
        pcall(ns.RefreshVisual, rule)
        for _, p in ipairs(self.linkRides or {}) do pcall(ns.RefreshVisual, p[1]) end
        if self.pairRule then pcall(ns.RefreshVisual, self.pairRule) end
        self.linkRides, self.linkHidden, self.linkStart, self.pairRule, self.pairFr = nil, nil, nil, nil, nil
        ns.SelectVisual(rule)
        if ns.EditRule then ns.EditRule(rule) end
        return
    end
    VP.CommitDrag(rule, self, SnapFn)
    if self.linkRides then
        for _, p in ipairs(self.linkRides) do VP.CommitDrag(p[1], p[2], nil) end
    end
    if self.linkHidden and self.linkStart then
        local dx, dy = (rule.visual.x or 0) - self.linkStart[1], (rule.visual.y or 0) - self.linkStart[2]
        for _, o in ipairs(self.linkHidden) do
            local ov = o.visual
            if ParentFor(o) == self.linkStart[3] then ov.x, ov.y = (ov.x or 0) + dx, (ov.y or 0) + dy; pcall(ns.RefreshVisual, o) end
        end
    end
    self.linkRides, self.linkHidden, self.linkStart = nil, nil, nil
    if self.pairFr then
        local pr, pf = self.pairRule, self.pairFr
        self.pairRule, self.pairFr = nil, nil
        VP.CommitDrag(pr, pf, nil)   -- the partner keeps the offset it had; it is re-anchored to its own container
    end
end
-- a group made or changed while everything is unlocked gets its mover tag (Visual.lua's refresh pass asks while ns.unlocked)
function M.AfterRefresh() RefreshGroupTags() end
M.MenuParts = VisualMenuParts   -- (the element menu's rows for a display: Visual.lua's DISPLAY_ELEMENT)

-------------------------------------------------------------------------------
-- Mover session (P4 / P5; Xaya 2026-11-06, her words: "arrow-key nudges yes; moves held until Save"; "lock icon in mover tool allows for
-- a temporary lock to account for potentially multiple rule groups stacked on top of each other; does not force a save. exiting out of
-- mover mode first creates a prompt to cancel or commit move changes. create a temp layout in drafts in case of game crash or something
-- which auto-deletes after a user clicked save").
-- - Opening the mover (/xui unlock, the Lock Positions buttons) keeps every display's and group's position aside (the draft,
--   CueRulesDB.moverDraft). Moves show at once; leaving the mover with any move asks "Save moves" (the draft is deleted) or "Cancel
--   moves" (all go back).
-- - (SD-58, V28) It works only while the settings window is open. Closing the window closes it: with no move it simply ends; with
--   moves (her answer for the mover, SD-15: "Keep, resume after") the moves stay on screen and in the draft, and it opens again with
--   them the next time the window opens, where Save / Cancel work as usual. INFERENCE: "resume after" for a window closed by hand means
--   the window's next opening (for combat it is the window's own reopening after the fight).
-- - The game writes saved data only at logout, /reload, a disconnect or quitting (not at a crash). A draft left by a /reload or a
--   logout without Save waits in the saved data (the displays keep the moved positions, which are saved); the mover opens with it the
--   next time the settings window opens. (Round 7: the login question about it is gone with the mover's code at login.) After a crash
--   nothing of the session was written: the last saved layout is what loads (the moves are lost, the layout is not damaged).
-- - The lock icon on a group's mover tag locks that group for now: its displays let the mouse through (to reach what is under them)
--   and its tag does not drag. It saves nothing and ends with the mover.
-- - Arrow keys nudge the display or group last clicked or dragged in the mover by 1 pixel (Shift: 10). Not in combat.
-------------------------------------------------------------------------------
local R_KEYS = { "x", "y", "anchor", "point", "anchorPlace" }
local F_KEYS = { "cX", "cY", "cRel", "cPoint", "cRelPoint", "cFrame", "cAnchorTo", "cGroup" }   -- (cGroup: B, so Cancel undoes a group anchor)
local function Copy(t) if type(t) ~= "table" then return t end local o = {}; for k, v in pairs(t) do o[k] = Copy(v) end; return o end
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function TakeDraft()
    local d = { at = time and time() or 0, rules = {}, folders = {} }
    for i, r in ipairs(ns.rules or {}) do
        local v = r.visual
        if type(v) == "table" then
            local e = { i = i, n = tostring(r.name), snap = Copy(v.snap) }
            for _, k in ipairs(R_KEYS) do e[k] = v[k] end
            d.rules[#d.rules + 1] = e
        end
    end
    for _, f in ipairs(ns.folders or {}) do
        if f.id then
            local e = {}
            for _, k in ipairs(F_KEYS) do e[k] = f[k] end
            d.folders[tostring(f.id)] = e
        end
    end
    return d
end
local function DraftRule(e)   -- the rule a draft entry is about (same place in the list and same name), or nil
    local r = ns.rules and ns.rules[e.i]
    if r and tostring(r.name) == e.n and type(r.visual) == "table" then return r end
end
-- what moved since the draft was taken: a list of { kind = "display" / "group", obj, entry }
function ns.MoverChanges(d)
    d = d or (CoreS.moverDraft)
    local out = {}
    if type(d) ~= "table" then return out end
    for _, e in ipairs(d.rules or {}) do
        local r = DraftRule(e)
        if r then
            local v, moved = r.visual, not Same(r.visual.snap, e.snap)
            for _, k in ipairs(R_KEYS) do if v[k] ~= e[k] then moved = true end end
            if moved then out[#out + 1] = { kind = "display", obj = r, entry = e } end
        end
    end
    for fid, e in pairs(d.folders or {}) do
        local f = ns.FolderById(fid) or ns.FolderById(tonumber(fid))
        if f then
            for _, k in ipairs(F_KEYS) do if f[k] ~= e[k] then out[#out + 1] = { kind = "group", obj = f, entry = e }; break end end
        end
    end
    return out
end
local function Restore(d)
    for _, c in ipairs(ns.MoverChanges(d)) do
        if c.kind == "display" then
            local v = c.obj.visual
            for _, k in ipairs(R_KEYS) do v[k] = c.entry[k] end
            v.snap = Copy(c.entry.snap)
        else
            local f, e = c.obj, c.entry
            if e.cRel == "group" and e.cGroup ~= nil and not ns.FolderById(e.cGroup) then
                -- (review fix 3a) the group it followed when the mover opened has been deleted since: its link is not brought back
                -- (her answer for a deleted followed group: "Stays put, link cleared"); it keeps its place on screen
                local ok = pcall(VP.Reanchor, f, function()
                    for _, k in ipairs(F_KEYS) do f[k] = e[k] end
                    f.cRel, f.cGroup = nil, nil
                end)
                if not ok or f.cRel == "group" then f.cRel, f.cGroup = nil, nil end
            else
                for _, k in ipairs(F_KEYS) do f[k] = e[k] end
                pcall(ns.GroupFrame, f)
            end
        end
    end
end
local function EndSession(save)
    local d = CoreS.moverDraft
    if d and not save then Restore(d) end
    if ns.SettingsReady("core") then CoreS.moverDraft = nil end
    wipe(mover.tempLock); mover.sel = nil; mover.paused = nil
    if ns.MarkDirty then ns.MarkDirty() end
    ns.Fire("CONFIG_CHANGED")
end
function ns.MoverTempLocked(rule)   -- the display sits in a group locked for now from the mover tag's lock icon
    if not (ns.unlocked and rule and rule.folder and next(mover.tempLock)) then return false end
    for fid in pairs(mover.tempLock) do if InFolder(rule.folder, fid) then return true end end
    return false
end
function ns.SetMoverTempLock(f, on)
    if not f then return end
    mover.tempLock[f.id] = on and true or nil
    if mover.sel and mover.sel.kind == "group" and mover.sel.obj == f and on then mover.sel = nil end
    for _, r in ipairs(ns.rules or {}) do
        if r.visual and frames[r] and InFolder(r.folder, f.id) then pcall(ns.RefreshVisual, r) end
    end
end
function ns.IsMoverTempLocked(f) return f and mover.tempLock[f.id] and true or false end
function ns.MoverSelect(kind, obj) if ns.unlocked and obj then mover.sel = { kind = kind, obj = obj } end end
function ns.MoverSelection() return mover.sel end
-- P4: move the selected display or group by dx / dy pixels (its own units)
function ns.MoverNudge(dx, dy)
    local s = mover.sel
    if not (ns.unlocked and s) then return false end
    if InCombat() then return false end
    if s.kind == "group" then
        if mover.tempLock[s.obj.id] then return false end
        s.obj.cX = (s.obj.cX or 0) + dx; s.obj.cY = (s.obj.cY or 0) + dy
        GroupPosChanged(s.obj)
        -- its X / Y box shows the new numbers (#13: its old ones stayed, and Apply would have moved the group back)
        if posPopup and posPopup:IsShown() and posPopup.fid == s.obj.id then FillPosPopup(posPopup) end
    else
        local r = s.obj
        if not (r.visual and frames[r]) or ns.MoverTempLocked(r) then return false end
        r.visual.x = (r.visual.x or 0) + dx; r.visual.y = (r.visual.y or 0) + dy
        VP.PlaceDisplay(r)
        ns.Fire("CONFIG_CHANGED")
    end
    return true
end
local NUDGE = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local function KeyFrame()   -- made on the first opening of the mover (V14); shown only while it is open
    if mover.keys then return mover.keys end
    local k = CreateFrame("Frame", "XayaUIMoverKeys", UIParent)
    -- (#13, Xaya 2026-11-08: "in mover mode, I can't use arrow keys") a size, a place and a high strata: the frame had none, and
    -- whether the game gives keys to a keyboard frame with no size, or ahead of other addons' keyboard frames below it, is not
    -- documented (INFERENCE: both made safe here; the mouse still goes through it, EnableMouse stays off)
    k:SetFrameStrata("FULLSCREEN_DIALOG"); k:SetSize(1, 1); k:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    -- (row 56, Xaya 2026-11-08: "WHY DOES THE ADDON KEEP PREVENTING ME FROM SCREENSHOTTING") the keys go through core's ns.KeyCatch
    -- (XayaUI/KeyCatch.lua): only an arrow that nudged something is held, for that key only; every other key, PRINTSCREEN included,
    -- reaches the game, also in combat
    local function OnKey(_, key, inCombat)
        local n = NUDGE[key]
        if not (n and not inCombat and mover.sel ~= nil) then return false end
        local step = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
        ns.MoverNudge(n[1] * step, n[2] * step)
        return true
    end
    if ns.KeyCatch then ns.KeyCatch(k, OnKey) end
    mover.keys = k
    return k
end
function ns.MoverKeyFrame() return mover.keys end
local EXIT_POPUP = "XAYAUI_MOVER_EXIT"
local function PromptAndThen(text, onSave, onCancel)
    StaticPopupDialogs[EXIT_POPUP] = StaticPopupDialogs[EXIT_POPUP] or {
        -- (no hide on Escape: an Escape must never throw moves away; the two buttons are her two choices)
        text = "%s", button1 = "Save moves", button2 = "Cancel moves", timeout = 0, whileDead = true, hideOnEscape = false,
        preferredIndex = 3,
        OnAccept = function(self, data) if data and data.save then data.save() end end,
        OnCancel = function(self, data, reason) if reason ~= "clicked" then return end if data and data.cancel then data.cancel() end end,
    }
    local dlg = StaticPopup_Show(EXIT_POPUP, text, nil, { save = onSave, cancel = onCancel })
    if dlg and dlg.SetFrameStrata then dlg:SetFrameStrata("TOOLTIP") end
    mover.prompt = EXIT_POPUP
end
function ns.MoverPromptShown() return mover.prompt end
local function AfterMoverChange()
    ns.RefreshAllVisuals()
    RefreshGroupTags()
    if ns.QoL_RefreshAll then pcall(ns.QoL_RefreshAll) end
    SyncEngine()
end
local function Lock()
    DropAllDrags()   -- (a drag still running ends with the mover: round 7 repair, V28)
    ns.unlocked = false
    for r in pairs(pairOf) do ns.ClearPair(r) end
    if mover.keys then mover.keys:Hide() end
    ns.Print("visuals locked.")
    AfterMoverChange()
    MenuOwnerCheck()   -- (V26) a display's menu opened in the mover goes with it
end
-- leave the mover: Save keeps the moves, Cancel puts every display and group back where it was when the mover opened
function M.MoverExit(choice)
    mover.prompt = nil
    if choice == "save" or choice == "cancel" then EndSession(choice == "save") end
    if ns.unlocked then Lock() end
end
local LOCK_MOVER = "the mover (/xui unlock) can't open during combat. It will open when combat ends."
local function HasMoves() return CoreS.moverDraft ~= nil and #ns.MoverChanges() > 0 end
-- (re)open the mover with the moves kept in the draft (or a new draft when there is none)
local function MoverResume()
    if ns.unlocked then return end
    if ns.RulesDisabled then   -- (/xui disable: it waits for /xui enable)
        ns.Print(HasMoves() and "the mover will open again with your unsaved moves when you type /xui enable."
            or "the mover will open again when you type /xui enable.")
        return
    end
    if InCombat() or not windowOpen then return end   -- (it opens with the settings window: after combat the window reopens by itself)
    mover.paused = nil
    if ns.SettingsReady("core") and not CoreS.moverDraft then CoreS.moverDraft = TakeDraft() end   -- (the draft was gone: start a new one)
    wipe(mover.tempLock); mover.sel = nil
    KeyFrame():Show()
    ns.unlocked = true
    local n = #ns.MoverChanges()
    ns.Print(n > 0 and ("the mover is open again with your %d unsaved move(s). Type /xui unlock to save or cancel them."):format(n)
        or "the mover is open again.")
    pcall(AfterMoverChange)
end
-- the mover on / off: the Lock Positions buttons and /xui unlock (through ns.OptionsApi.Unlock); reached as ns.ToggleUnlock, XayaUI Rules'
-- name for it (Visual.lua forwards to M.ToggleUnlock)
local function ToggleUnlock()
    if not ns.unlocked then
        -- (V26) never opens while rules are off (/xui disable) or in combat; a mover paused by either opens again with its moves
        if ns.RulesDisabled then
            ns.Print("rules are off (/xui disable), so the mover can't open. Type /xui enable first.")
            return
        end
        if InCombat() then
            ns.CombatLock("unlock", function() if not ns.unlocked then ToggleUnlock() end end, LOCK_MOVER)
            return
        end
        -- (SD-58; SD-64, option 1) the mover works only while the settings window is open: it opens the window first. The window's
        -- opening already brings back a mover with kept moves (WindowOpened below).
        if not windowOpen then
            if ns.OptionsApi.IsOpen and not ns.OptionsApi.IsOpen() and ns.OptionsApi.Toggle then ns.OptionsApi.Toggle() end
            if ns.unlocked or not windowOpen then return end
        end
        if mover.paused or HasMoves() then MoverResume(); return end
    end
    if ns.unlocked then
        -- P5: leaving the mover with moves asks first
        local n = #ns.MoverChanges()
        if n > 0 then
            PromptAndThen(("You moved %d display(s) or group(s) in the mover view. Save the moves, or cancel them (everything goes back to where it was)?"):format(n),
                function() ns.MoverExit("save") end, function() ns.MoverExit("cancel") end)
            return
        end
        ns.MoverExit("save")
        return
    end
    if ns.SettingsReady("core") then CoreS.moverDraft = TakeDraft() end
    wipe(mover.tempLock); mover.sel = nil
    KeyFrame():Show()
    ns.unlocked = true
    ns.Print("visuals UNLOCKED: drag them, then /xui unlock again to lock (you are asked to save or cancel the moves). Arrow keys nudge the display or group you last clicked (Shift: 10 pixels). Hover a display or a group's name tab to see what it is; click it to open its settings; the lock on a group's tab locks it for now.")
    AfterMoverChange()
end
-- (SD-64, option 1) /xui unlock (XayaUI/Core.lua, through ns.Options.Unlock): out of combat it opens the settings window with the
-- mover on, or, with the window open, turns the mover on or off as the Lock Positions buttons do. openOnly (the request she made in
-- combat, run when combat ends): it opens, never turns an open mover off.
M.ToggleUnlock = ToggleUnlock
function ns.OptionsApi.Unlock(openOnly)
    if openOnly and ns.unlocked then return end
    ToggleUnlock()
end
function ns.OptionsApi.MoverOn() return ns.unlocked and true or false end

-------------------------------------------------------------------------------
-- (V26, V28) The mover closes: combat starts (the settings window closes then, Options.lua Tree.CombatStart, and the mover with it), the
-- window is closed by hand, or /xui disable. reason "combat" / "window" / "off". With "combat" and "off" it opens again by itself (with
-- its moves, if any) when the window is next open and rules are on: after combat the window reopens where she was. With "window" it
-- opens again only when it has unsaved moves (SD-15 "Keep, resume after"); with no move it simply ends. A drag still running is dropped
-- (that one display goes back to its last place); the group X / Y box and the frame picker close; its key frame hides at once, so it
-- takes no key in a fight (core KeyCatch.lua lets go of the keyboard on hide). The Save / Cancel question goes too: it is asked again
-- when she next leaves the mover.
-------------------------------------------------------------------------------
-- combat is starting now: PLAYER_REGEN_DISABLED comes before the lockdown, so the lockdown check alone is still false then.
-- UnitAffectingCombat (globals.md: SecretArguments=AllowedWhenUntainted, no secret return) is true by then (INFERENCE, unverified in game)
local issecretV = ns.IsSecret or issecretvalue or function() return false end
function ns.MoverCombatStarting()
    if InCombat() then return true end
    if not UnitAffectingCombat then return false end
    local ok, v = pcall(UnitAffectingCombat, "player")
    return (ok and not issecretV(v) and v) and true or false
end
function ns.MoverCombatClose(reason)
    if picker and picker:IsShown() then picker:Hide() end
    if posPopup and posPopup:IsShown() then posPopup:Hide() end
    if not ns.unlocked then return false end
    if mover.prompt == EXIT_POPUP then
        mover.prompt = nil
        if StaticPopup_Hide then pcall(StaticPopup_Hide, EXIT_POPUP) end
    end
    DropAllDrags()   -- a drag still running stops here (before the lockdown); RefreshAllVisuals puts it back
    local n = #ns.MoverChanges()
    if reason == "window" and n == 0 then   -- closed by hand with nothing moved: it simply ends (the draft goes)
        EndSession(true)
        Lock()
        return true
    end
    mover.paused = true
    ns.unlocked = false
    for r in pairs(pairOf) do ns.ClearPair(r) end
    if mover.keys then mover.keys:Hide() end   -- (no key is taken in the fight)
    pcall(AfterMoverChange)
    MenuOwnerCheck()   -- (V26) a display's menu opened in the mover goes with it (combat: the owner's own event hides it too)
    if reason == "off" then
        ns.Print(n > 0 and "the mover closed because rules are off. It will open again with your unsaved moves when you type /xui enable."
            or "the mover closed because rules are off. It will open again when you type /xui enable.")
    elseif reason == "window" then
        ns.Print(("the mover closed with the settings window. Your %d unsaved move(s) are kept, and the mover opens again with them the next time you open the settings window."):format(n))
    else
        ns.Print(n > 0 and "the mover closed because combat started. It will open again with your unsaved moves when combat ends."
            or "the mover closed because combat started. It will open again when combat ends.")
    end
    return true
end
function ns.MoverPaused() return mover.paused ~= nil end   -- (tests)
-- the settings window opened: a mover paused by combat or /xui disable, or with moves kept in the draft (from a closed window, a
-- /reload or a logout without Save), opens again with them
WindowOpened = function()
    if ns.unlocked then return end
    if mover.paused then MoverResume(); return end
    if CoreS.moverDraft then
        if #ns.MoverChanges() > 0 then MoverResume()
        elseif ns.SettingsReady("core") then CoreS.moverDraft = nil end   -- (a draft with no moves is dropped silently)
    end
end
-- the settings window closed (ns.EndWindowState, above): the sidebar's per-rule and per-group movement unlocks end, then the mover
WindowClosed = function()
    local rules = {}
    for r in pairs(ns.moveUnlocked) do rules[#rules + 1] = r end
    if #rules > 0 then ns.SetMoveUnlocked(rules, false) end
    local fids = {}
    for fid in pairs(ns.groupUnlocked) do fids[#fids + 1] = fid end
    for _, fid in ipairs(fids) do
        local f = ns.FolderById and ns.FolderById(fid)
        if f then ns.SetGroupUnlocked(f, false) else ns.groupUnlocked[fid] = nil end
    end
    ns.MoverCombatClose(ns.MoverCombatStarting() and "combat" or "window")   -- (also the picker and the X / Y box)
    MenuOwnerCheck()   -- (V26) a context menu opened from the window goes with it
end
-- /xui disable: the mover, the X / Y box, the picker and the sidebar's per-rule and per-group movement unlocks (sample displays) end;
-- nothing shows until /xui enable (XayaUI_Rules/Visual.lua hides every display on the same event). Placed once (the game has no way to
-- remove a listener); each returns at once while none of this is open.
ns.On("RULES_DISABLED", function()
    if not (ns.unlocked or next(ns.moveUnlocked) or next(ns.groupUnlocked) or (picker and picker:IsShown()) or (posPopup and posPopup:IsShown())) then return end
    ns.MoverCombatClose("off")
    local rules = {}
    for r in pairs(ns.moveUnlocked) do rules[#rules + 1] = r end
    if #rules > 0 then pcall(ns.SetMoveUnlocked, rules, false) end
    for fid in pairs(ns.groupUnlocked) do
        local f = ns.FolderById and ns.FolderById(fid)
        if f then pcall(ns.SetGroupUnlocked, f, false) else ns.groupUnlocked[fid] = nil end
    end
end)
ns.On("RULES_ENABLED", function() if mover.paused and windowOpen then MoverResume() end end)
ns.MoverDisplay = M   -- (XayaUI Rules' seam, Visual.lua: false until now)
