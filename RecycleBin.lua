-------------------------------------------------------------------------------
-- RecycleBin.lua : soft-delete for rules, folders, buff bars and QoL stats boxes.
--
-- Deleting one of these no longer throws it away: it is moved out of ns.rules /
-- ns.folders / ns.bars / ns.qolBoxes and into CueRulesDB.recycleBin.items instead.
-- While it sits there the engine, Visual.lua, Bars.lua and QoL.lua never see it
-- (it isn't in any of the live arrays they read), so it cannot load, render, fire
-- or be edited. It is gone for good only once it has aged past the configured
-- window (weekly by default) or Xaya empties the bin herself.
--
-- Deleting a folder still keeps the existing behavior of moving its rules and
-- subfolders up one level rather than trashing them too; only the folder itself
-- becomes recoverable.
-------------------------------------------------------------------------------
local addonName, ns = ...

local PURGE_SECONDS = {
    nightly    = 1 * 86400,
    semiweekly = 3.5 * 86400,
    weekly     = 7 * 86400,
}
ns.RECYCLE_PURGE_MODES = {
    weekly     = "Weekly (default)",
    semiweekly = "Semi-weekly (about every 3.5 days)",
    nightly    = "Nightly (not recommended - use Empty Recycle Bin instead)",
}
ns.RECYCLE_PURGE_ORDER = { "weekly", "semiweekly", "nightly" }
ns.RECYCLE_KIND_LABEL = { rule = "Rule", folder = "Folder", bar = "Buff Bar", qol = "QoL Stats Box" }

function ns.RecycleBinDB()
    CueRulesDB.recycleBin = CueRulesDB.recycleBin or {}
    local bin = CueRulesDB.recycleBin
    bin.items = bin.items or {}
    bin.purgeMode = bin.purgeMode or "weekly"
    return bin
end

local function PurgeWindow()
    return PURGE_SECONDS[ns.RecycleBinDB().purgeMode] or PURGE_SECONDS.weekly
end

-- Permanently removes anything that has sat in the bin longer than the configured window. Cheap; safe to call often.
function ns.Recycle_Purge()
    local bin = ns.RecycleBinDB()
    local window, now = PurgeWindow(), time()
    for i = #bin.items, 1, -1 do
        local it = bin.items[i]
        if now - (it.deletedAt or now) >= window then table.remove(bin.items, i) end
    end
end

local function NewItemId()
    return "rb" .. tostring(time()) .. tostring(math.random(1000, 9999))
end

local function Stash(kind, name, data)
    local bin = ns.RecycleBinDB()
    bin.items[#bin.items + 1] = { id = NewItemId(), kind = kind, name = name or "?", deletedAt = time(), data = data }
    ns.Recycle_Purge()
    ns.MarkDirty()
end

-- Moves a live rule out of ns.rules and into the bin, dropping its on-screen visual first.
function ns.Recycle_TrashRule(rule)
    for idx, r in ipairs(ns.rules) do if r == rule then table.remove(ns.rules, idx); break end end
    ns.DropVisual(rule)
    Stash("rule", rule.name, rule)
end

-- Moves a folder out of ns.folders. Its rules and subfolders are reparented to move up one level first
-- (same as before), so only the folder itself ends up in the bin.
function ns.Recycle_TrashFolder(folder)
    for _, r in ipairs(ns.rules) do if r.folder == folder.id then r.folder = folder.parent end end
    for _, f in ipairs(ns.folders) do if f.parent == folder.id then f.parent = folder.parent end end
    for idx, f in ipairs(ns.folders) do if f == folder then table.remove(ns.folders, idx); break end end
    Stash("folder", folder.name, folder)
end

function ns.Recycle_TrashBar(bar)
    for idx, b in ipairs(ns.bars) do if b == bar then table.remove(ns.bars, idx); break end end
    if ns.Bars_Drop then ns.Bars_Drop(bar) end
    Stash("bar", bar.name, bar)
end

function ns.Recycle_TrashBox(box)
    for idx, b in ipairs(ns.qolBoxes) do if b == box then table.remove(ns.qolBoxes, idx); break end end
    ns.QoL_Drop(box)
    Stash("qol", box.name, box)
end

-- Moves a bin item back into its live list. An orphaned rule or folder (its old parent folder was purged
-- or deleted permanently) reattaches at the top level instead of failing.
function ns.Recycle_Restore(id)
    local bin = ns.RecycleBinDB()
    for idx, it in ipairs(bin.items) do
        if it.id == id then
            local data = it.data
            if it.kind == "rule" then
                ns.NormalizeRule(data)
                if data.folder and not ns.FolderById(data.folder) then data.folder = nil end
                ns.rules[#ns.rules + 1] = data
                pcall(ns.RefreshVisual, data)
            elseif it.kind == "folder" then
                if data.parent and not ns.FolderById(data.parent) then data.parent = nil end
                ns.folders[#ns.folders + 1] = data
            elseif it.kind == "bar" then
                ns.Merge(data, ns.BAR_DEFAULTS)
                ns.bars[#ns.bars + 1] = data
                if ns.Bars_Refresh then ns.Bars_Refresh(data) end
            elseif it.kind == "qol" then
                ns.Merge(data, ns.QOL_BOX_DEFAULTS)
                ns.qolBoxes[#ns.qolBoxes + 1] = data
                ns.QoL_Refresh(data)
            end
            table.remove(bin.items, idx)
            ns.MarkDirty()
            if ns.OnRulesChanged then ns.OnRulesChanged() end
            return it.kind
        end
    end
end

function ns.Recycle_DeleteForever(id)
    local bin = ns.RecycleBinDB()
    for idx, it in ipairs(bin.items) do if it.id == id then table.remove(bin.items, idx); return true end end
    return false
end

function ns.Recycle_Empty()
    wipe(ns.RecycleBinDB().items)
end

-- Fractional days left before an item is auto-purged (for display; never negative).
function ns.Recycle_DaysLeft(item)
    local left = PurgeWindow() - (time() - (item.deletedAt or time()))
    return math.max(0, left / 86400)
end

function ns.Recycle_OnDBReady()
    ns.Recycle_Purge()
    C_Timer.NewTicker(1800, ns.Recycle_Purge) -- catches long sessions that cross the purge window without a reload
end

-------------------------------------------------------------------------------
-- Options page (an AceConfig group; built here, same reason as CursorTrackerGroup
-- in CursorTracker.lua - keeps Options.lua under Lua's 200-locals-per-function limit).
-------------------------------------------------------------------------------
function ns.RecycleBinGroup(Notify)
    local function bin() return ns.RecycleBinDB() end

    local function daysText(it)
        local d = ns.Recycle_DaysLeft(it)
        if d <= 0 then return "purging soon" end
        if d < 1 then return ("purges in about %dh"):format(math.ceil(d * 24)) end
        return ("purges in about %.1f day(s)"):format(d)
    end

    local a = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Deleted rules, folders, buff bars and QoL stats boxes land here first instead of vanishing. While something sits in the bin it is completely off: it does not load, does not show on screen, does not fire, and cannot be edited. Restore it to bring it back, or empty the bin to remove it for good." },
        purgeMode = { type = "select", name = "Auto-purge items after", order = 1, width = "double",
            values = ns.RECYCLE_PURGE_MODES, sorting = ns.RECYCLE_PURGE_ORDER,
            get = function() return bin().purgeMode end,
            set = function(_, v) bin().purgeMode = v; Notify() end },
        purgeNote = { type = "description", order = 1.5, width = "full", fontSize = "small",
            name = "Nightly is not recommended: with a window that short, use Empty Recycle Bin below on your own schedule instead of relying on the timer." },
        empty = { type = "execute", name = "Empty Recycle Bin (permanent)", order = 2, width = "double",
            disabled = function() return #bin().items == 0 end,
            confirm = true, confirmText = "Permanently delete everything in the Recycle Bin? This cannot be undone.",
            func = function() ns.Recycle_Empty(); Notify() end },
        emptyNote = { type = "description", order = 2.5, width = "full",
            hidden = function() return #bin().items > 0 end,
            name = "The Recycle Bin is empty." },
    }

    local items = {}
    for i, it in ipairs(bin().items) do items[#items + 1] = it end
    table.sort(items, function(x, y) return (x.deletedAt or 0) > (y.deletedAt or 0) end)

    for i, it in ipairs(items) do
        local label = ns.RECYCLE_KIND_LABEL[it.kind] or it.kind or "Item"
        a["item" .. i] = {
            type = "group", inline = true, order = 10 + i,
            name = ("[%s] %s"):format(label, it.name or "?"),
            args = {
                info = { type = "description", order = 1, width = "full",
                    name = ("Deleted %s. %s"):format(date("%Y-%m-%d %H:%M", it.deletedAt or time()), daysText(it)) },
                restore = { type = "execute", name = "Restore", order = 2, width = "half",
                    func = function() ns.Recycle_Restore(it.id); Notify() end },
                delete = { type = "execute", name = "Delete Forever", order = 3, width = "half",
                    confirm = true, confirmText = "Permanently delete this " .. label:lower() .. "? This cannot be undone.",
                    func = function() ns.Recycle_DeleteForever(it.id); Notify() end },
            },
        }
    end

    return { type = "group", name = "Recycle Bin", order = 4, args = a }
end
