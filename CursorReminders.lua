-------------------------------------------------------------------------------
-- CursorReminders.lua : turn the visual side of your rules into at-cursor reminders.
--
-- Ticked "Convert logged rules into at-cursor reminders" does one of two things (tick box "Duplicate instead"):
--   DUPLICATE (default, non-destructive): every rule with a display is copied into
--     MOUSE CURSOR > At-Cursor Reminders; the copy shows the rule's spell icon (spellID, or the aura ID when the
--     rule has no spell ID) instead of its texture. Copies are display-only (the folder is in the Mouse Cursor
--     category) and are tagged `cursorFrom`. Unticking deletes the copies. "Re-sync" rebuilds them.
--   CONVERT: the original rules stay where they are, but their display art becomes the spell icon and the icon is
--     laid out next to the cursor. The old display settings are kept in `rule.cursorBackup` and restored when
--     the option is unticked. (Edits you make to a converted display while converted are lost on restore.)
--
-- Layout: the folder "At-Cursor Reminders" is a DYNAMIC group (Visual.lua) anchored to an invisible frame that
-- follows the mouse (global XayaUICursorAnchor). Side: above / below / left / right of the cursor, with distance,
-- icon size and spacing. Above / below lay icons out in a row, left / right in a column.
-------------------------------------------------------------------------------
local addonName, ns = ...

local ANCHOR_NAME = "XayaUICursorAnchor"
local SUB_NAME = "At-Cursor Reminders"
local anchor

for k, v in pairs({
    remOn = false, remDup = true, remSide = "above", remDist = 30, remSize = 32, remSpacing = 4, remFolderId = "",
}) do ns.CURSOR_DEFAULTS[k] = v end

local function Cfg() return CueRulesDB and CueRulesDB.cursor end

-- the invisible cursor-following anchor (created at load so folders can look it up by name)
anchor = CreateFrame("Frame", ANCHOR_NAME, UIParent)
anchor:SetSize(1, 1)
anchor:EnableMouse(false)
anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
local function Follow(self)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
end
local function SetTracking(on)
    if on then Follow(anchor); anchor:SetScript("OnUpdate", Follow) else anchor:SetScript("OnUpdate", nil) end
end

function ns.CursorReminderFolder()
    local c = Cfg()
    if not (c and c.remOn) then return nil end
    return ns.FolderById(c.remFolderId)
end

local function IconSpell(r)
    local a = tonumber(r.spellID) or 0
    if a == 0 then a = tonumber(r.buffID) or 0 end
    return a
end

local function IsSource(r)
    if r.cursorFrom then return false end
    if not (r.visual and r.visual.enabled) then return false end
    local top = ns.TopFolder(r.folder)
    if top and top.default == "cursor" then return false end
    if not ns.KindHas(r, "visual") then return false end
    return IconSpell(r) ~= 0
end

local function IconVisual(v, size)
    v.kind = "spellicon"; v.tex = ""
    v.w, v.h, v.x, v.y = size, size, 0, 0
    v.rotation, v.flipH, v.flipV = 0, false, false
    if type(v.overlay) == "table" then v.overlay.enabled = false end
end

local function NewId() return "c" .. tostring(time()) .. tostring(math.random(1000, 9999)) end

local function EnsureFolders()
    local cfg = Cfg()
    local top
    for _, f in ipairs(ns.folders) do if not f.parent and f.default == "cursor" then top = f; break end end
    if not top then top = ns.NewFolder("Mouse Cursor"); top.default = "cursor" end
    local sub = ns.FolderById(cfg.remFolderId)
    if not sub or sub.parent ~= top.id then
        sub = nil
        for _, f in ipairs(ns.folders) do if f.parent == top.id and f.name == SUB_NAME then sub = f; break end end
        if not sub then sub = ns.NewFolder(SUB_NAME, top.id) end
        cfg.remFolderId = sub.id
    end
    return top, sub
end

local function Configure()
    local cfg = Cfg()
    local f = cfg and ns.FolderById(cfg.remFolderId)
    if not f then return end
    local size, dist = cfg.remSize or 32, cfg.remDist or 30
    f.cType, f.cRel, f.cFrame = "dynamic", "custom", ANCHOR_NAME
    f.cPoint, f.cRelPoint, f.cScale, f.cAlpha = "CENTER", "CENTER", 1, 1
    f.cSpacing, f.cW, f.cH = cfg.remSpacing or 4, 0, 0
    local side = cfg.remSide or "above"
    -- Visual.lua's dynamic layout puts a row's TOP edge on the container centre (row: HCENTER) and a column's LEFT edge on it (column: VCENTER)
    if side == "above" then f.cGrowth, f.cX, f.cY = "HCENTER", 0, dist + size
    elseif side == "below" then f.cGrowth, f.cX, f.cY = "HCENTER", 0, -dist
    elseif side == "right" then f.cGrowth, f.cX, f.cY = "VCENTER", dist, 0
    else f.cGrowth, f.cX, f.cY = "VCENTER", -dist - size, 0 end
end

function ns.CursorReminders_Revert()
    for i = #ns.rules, 1, -1 do
        local r = ns.rules[i]
        if r.cursorFrom then
            pcall(ns.DropVisual, r)
            table.remove(ns.rules, i)
        elseif r.cursorConv then
            if r.cursorBackup and r.cursorBackup.visual then r.visual = r.cursorBackup.visual end
            r.cursorConv, r.cursorBackup = nil, nil
        end
    end
    SetTracking(false)
    if ns.RefreshAllVisuals then ns.RefreshAllVisuals() end
    if ns.MarkDirty then ns.MarkDirty() end
end

function ns.CursorReminders_Count()
    local n, skipped = 0, 0
    for _, r in ipairs(ns.rules or {}) do
        if r.cursorFrom or r.cursorConv then n = n + 1
        elseif r.visual and r.visual.enabled and IconSpell(r) == 0 then skipped = skipped + 1 end
    end
    return n, skipped
end

function ns.CursorReminders_Apply()
    local cfg = Cfg()
    if not cfg then return end
    ns.CursorReminders_Revert()
    if cfg.remOn then
        local _, sub = EnsureFolders()
        Configure()
        SetTracking(true)
        local size = cfg.remSize or 32
        local list = {}
        for _, r in ipairs(ns.rules) do if IsSource(r) then list[#list + 1] = r end end
        for _, r in ipairs(list) do
            if cfg.remDup then
                r.cid = r.cid or NewId()
                local d = ns.Copy(r)
                d.cid, d.cursorBackup, d.cursorConv, d.editLocked = nil, nil, nil, nil
                d.cursorFrom = r.cid
                d.folder = sub.id
                d.name = ((r.name and r.name ~= "") and r.name or "Rule") .. " (cursor)"
                d.sound = d.sound or {}
                d.sound.enabled = false
                IconVisual(d.visual, size)
                ns.NormalizeRule(d)
                ns.rules[#ns.rules + 1] = d
            else
                r.cursorBackup = { visual = ns.Copy(r.visual) }
                IconVisual(r.visual, size)
                r.cursorConv = true
            end
        end
        if ns.RefreshAllVisuals then ns.RefreshAllVisuals() end
        if ns.MarkDirty then ns.MarkDirty() end
    end
end

-- light update (side, distance, spacing, icon size): no rebuild of the copies
function ns.CursorReminders_Layout()
    local cfg = Cfg()
    if not (cfg and cfg.remOn) then return end
    Configure()
    local size = cfg.remSize or 32
    for _, r in ipairs(ns.rules) do
        if (r.cursorFrom or r.cursorConv) and r.visual then r.visual.w, r.visual.h = size, size end
    end
    if ns.RefreshAllVisuals then ns.RefreshAllVisuals() end
end

function ns.CursorReminders_OnDBReady()
    local cfg = Cfg()
    if cfg and cfg.remOn then SetTracking(true); Configure() end
end

-------------------------------------------------------------------------------
-- options: an extra inline group on the Cursor Tracker page
-------------------------------------------------------------------------------
local origGroup = ns.CursorTrackerGroup
function ns.CursorTrackerGroup(Notify)
    local g = origGroup(Notify)
    local function C() return CueRulesDB.cursor or ns.CURSOR_DEFAULTS end
    local function off() return not C().remOn end
    local SIDE_V = { above = "Above the cursor", below = "Below the cursor", left = "Left of the cursor", right = "Right of the cursor" }
    local SIDE_O = { "above", "below", "left", "right" }
    g.args.reminders = { type = "group", inline = true, name = "At-Cursor Reminders", order = 36, args = {
        intro = { type = "description", order = 0, width = "full",
            name = function()
                local n, skipped = ns.CursorReminders_Count()
                return ("Shows the spell icon of every rule that has a display next to your cursor. Currently %d reminder(s)%s."):format(n,
                    skipped > 0 and (", " .. skipped .. " display rule(s) skipped because they have no spell or aura ID") or "")
            end },
        remOn = { type = "toggle", name = "Convert logged rules into at-cursor reminders", order = 1, width = "full",
            desc = "Uses the visual side of your rules (rules that have a display switched on). Sound is not affected.",
            get = function() return C().remOn and true or false end,
            set = function(_, v) C().remOn = v; ns.CursorReminders_Apply(); Notify() end },
        remDup = { type = "toggle", name = "Duplicate instead of converting (keeps your originals)", order = 2, width = "full",
            desc = "Ticked: every display rule is copied into Mouse Cursor > At-Cursor Reminders and the copy becomes a spell icon. Unticked: the original rules' textures are converted to spell icons in place and moved next to the cursor (restored when you untick the switch above).",
            get = function() return C().remDup and true or false end,
            set = function(_, v) C().remDup = v; if C().remOn then ns.CursorReminders_Apply() end; Notify() end },
        remSide = { type = "select", name = "Position", order = 3, values = SIDE_V, sorting = SIDE_O, disabled = off,
            get = function() return C().remSide end,
            set = function(_, v) C().remSide = v; ns.CursorReminders_Layout(); Notify() end },
        remDist = { type = "range", name = "Distance from cursor (px)", order = 4, min = 0, max = 200, step = 1, disabled = off,
            get = function() return C().remDist or 30 end,
            set = function(_, v) C().remDist = v; ns.CursorReminders_Layout() end },
        remSize = { type = "range", name = "Icon size (px)", order = 5, min = 16, max = 96, step = 1, disabled = off,
            get = function() return C().remSize or 32 end,
            set = function(_, v) C().remSize = v; ns.CursorReminders_Layout() end },
        remSpacing = { type = "range", name = "Spacing between icons (px)", order = 6, min = 0, max = 40, step = 1, disabled = off,
            get = function() return C().remSpacing or 4 end,
            set = function(_, v) C().remSpacing = v; ns.CursorReminders_Layout() end },
        resync = { type = "execute", name = "Re-sync now", order = 7, disabled = off,
            desc = "Rebuilds the reminders from your current rules (picks up rules you added or changed since the switch was ticked).",
            func = function() ns.CursorReminders_Apply(); Notify() end },
    } }
    return g
end
