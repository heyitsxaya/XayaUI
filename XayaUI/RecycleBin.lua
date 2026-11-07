-- XayaUI: RecycleBin -- deleting a rule or a group moves it here instead of throwing it away (GitHub #88).
--
-- What goes in (each delete is ONE bin item, restored as a whole):
--   * a rule, with its cues and conditions (the rows whose parentUid chain leads to it);
--   * a group deleted on its own: only the group; its rules and nested groups move up one level as before, and Restore moves the
--     ones that are still where they were moved back into it;
--   * a group deleted with its contents: the group, every group nested in it and every rule inside them.
-- Removing a single cue or condition inside a rule is an edit and does not go here; neither do drafts or backups.
-- While an item is in the bin it is in neither ns.rules nor ns.folders, so nothing loads, shows, fires or can be edited.
--
-- How long items stay (Xaya, 2026-11-04): 7 days by default; 36 hours, 3 days or 14 days in the Recycle Bin page. Older items are
-- removed for good at login and every 30 minutes. Empty Recycle Bin removes everything at once, after a confirmation.
-- Saved in CueRulesDB.recycleBin (account-wide, like the rules).
local _, ns = ...
ns = XayaUI_NS or ns

local KEEP = {   -- hours, label (the page shows them in this order)
    { 36, "36 hours" },
    { 72, "3 days" },
    { 168, "7 days" },
    { 336, "14 days" },
}
local DEFAULT_KEEP = 168
ns.RECYCLE_KEEP = KEEP

local function now() return (time and time()) or 0 end

function ns.RecycleDB()
    if type(CueRulesDB) ~= "table" then return nil end
    local b = CueRulesDB.recycleBin
    if type(b) ~= "table" then b = {}; CueRulesDB.recycleBin = b end
    if type(b.items) ~= "table" then b.items = {} end
    if type(b.nextId) ~= "number" then b.nextId = 1 end
    return b
end

local function validKeep(h)
    for _, k in ipairs(KEEP) do if k[1] == h then return true end end
    return false
end
function ns.RecycleKeepHours()
    local b = ns.RecycleDB()
    local h = b and b.keepHours
    return validKeep(h) and h or DEFAULT_KEEP
end
function ns.RecycleKeepLabel()
    local h = ns.RecycleKeepHours()
    for _, k in ipairs(KEEP) do if k[1] == h then return k[2] end end
    return tostring(h) .. " hours"
end
-- The sentence every delete prompt ends with.
function ns.RecycleBinNote() return "It goes to the Recycle Bin for " .. ns.RecycleKeepLabel() .. " (Rules > Recycle Bin)." end
-- FA-14 (core 0.6.62; Xaya: "Ask first (Recommended)"): how many items a keep time of h hours would remove for good right now
function ns.RecycleWouldPurge(h, at)
    local b = ns.RecycleDB()
    if not (b and validKeep(h)) then return 0 end
    local limit = (at or now()) - h * 3600
    local n = 0
    for _, it in ipairs(b.items) do local d = it.deletedAt; if type(d) ~= "number" or d <= limit then n = n + 1 end end
    return n
end
function ns.SetRecycleKeepHours(h)
    local b = ns.RecycleDB()
    if b and validKeep(h) then b.keepHours = h; ns.RecyclePurge() end
end

local function removeFrom(list, obj)
    for i = 1, #list do if list[i] == obj then table.remove(list, i); return true end end
    return false
end

-- the rule and every row whose parentUid chain leads to it (cues, conditions, and anything under them)
local function withDescendants(rule)
    local out, seen = { rule }, { [rule] = true }
    local uids = {}
    if type(rule.uid) == "string" then uids[rule.uid] = true end
    local grew = true
    while grew do
        grew = false
        for _, r in ipairs(ns.rules or {}) do
            if not seen[r] and r.parentUid and uids[r.parentUid] then
                seen[r] = true; out[#out + 1] = r; grew = true
                if type(r.uid) == "string" then uids[r.uid] = true end
            end
        end
    end
    return out
end

local function takeRules(list)
    local taken = {}
    for _, top in ipairs(list) do
        for _, r in ipairs(withDescendants(top)) do
            if removeFrom(ns.rules, r) then
                taken[#taken + 1] = r
                if ns.EndRule then pcall(ns.EndRule, r) end   -- (audit D56) its actions finish, a glow stops
                if ns.DropVisual then pcall(ns.DropVisual, r) end
            end
        end
    end
    return taken
end

local function addItem(item)
    local b = ns.RecycleDB()
    if not b then return nil end
    item.id = b.nextId
    b.nextId = b.nextId + 1
    item.deletedAt = now()
    b.items[#b.items + 1] = item
    if ns.MarkDirty then ns.MarkDirty() end
    return item
end

local function ruleName(r) return (type(r.name) == "string" and r.name ~= "") and r.name or "Unnamed rule" end

-- One rule (with its cues and conditions). Returns the bin item.
function ns.RecycleRule(rule)
    if type(rule) ~= "table" or not ns.rules then return nil end
    local taken = takeRules({ rule })
    if #taken == 0 then return nil end
    return addItem({ kind = "rule", name = ruleName(rule), rules = taken })
end

-- Several rules (multi-select): one bin item per rule, so each can be restored on its own. Returns how many went in.
function ns.RecycleRules(list)
    local n = 0
    for _, r in ipairs(list or {}) do
        local inBin = true
        for _, x in ipairs(ns.rules or {}) do if x == r then inBin = false; break end end
        if not inBin and ns.RecycleRule(r) then n = n + 1 end   -- (a rule already taken as another's cue is skipped)
    end
    return n
end

-- A group on its own: its rules and nested groups move up one level (as before); the group goes to the bin.
function ns.RecycleFolder(f)
    if type(f) ~= "table" or not ns.folders then return nil end
    local movedRules, movedFolders = {}, {}
    for _, r in ipairs(ns.rules or {}) do
        if r.folder == f.id then
            r.folder = f.parent
            -- audit D55 (core 0.6.62): every moved rule is recorded, so Restore brings it back; a rule with no uid yet (no cue or
            -- condition) gets one here (before: only rules that already had a uid went back into the restored group)
            if type(r.uid) ~= "string" and ns.NewUID then r.uid = ns.NewUID() end
            if type(r.uid) == "string" then movedRules[#movedRules + 1] = r.uid end
        end
    end
    for _, ff in ipairs(ns.folders) do
        if ff.parent == f.id then ff.parent = f.parent; movedFolders[#movedFolders + 1] = ff.id end
    end
    if not removeFrom(ns.folders, f) then return nil end
    return addItem({ kind = "group", name = tostring(f.name or "Group"), folders = { f }, rules = {},
        origParent = f.parent, movedRules = movedRules, movedFolders = movedFolders })
end

-- A group with everything inside it: one bin item. Returns the item and the number of rules it holds.
function ns.RecycleFolderAll(f)
    if type(f) ~= "table" or not ns.folders then return nil, 0 end
    local ids, order, stack = { [f.id] = true }, { f }, { f.id }
    while #stack > 0 do
        local cur = table.remove(stack)
        for _, ff in ipairs(ns.folders) do
            if ff.parent == cur and not ids[ff.id] then ids[ff.id] = true; order[#order + 1] = ff; stack[#stack + 1] = ff.id end
        end
    end
    local tops = {}
    for _, r in ipairs(ns.rules or {}) do if r.folder and ids[r.folder] and not r.parentUid then tops[#tops + 1] = r end end
    local taken = takeRules(tops)
    for _, r in ipairs(ns.rules or {}) do if r.folder and ids[r.folder] then r.folder = nil end end   -- stray cue rows, if any (as before)
    for _, ff in ipairs(order) do removeFrom(ns.folders, ff) end
    local item = addItem({ kind = "groupAll", name = tostring(f.name or "Group"), folders = order, rules = taken })
    return item, #tops
end

local function findItem(id)
    local b = ns.RecycleDB()
    if not b then return nil end
    for i, it in ipairs(b.items) do if it.id == id then return it, i, b end end
end

local function folderExists(id)
    if id == nil then return true end
    for _, f in ipairs(ns.folders or {}) do if f.id == id then return true end end
    return false
end

-- Puts an item back. A group it belonged to that no longer exists means top level. A clash with an ID now in use gets a new ID
-- (and everything pointing at the old one follows). Returns true and a short note for the player.
function ns.RecycleRestore(id)
    local it, idx, b = findItem(id)
    if not it then return false, "that item is no longer in the Recycle Bin" end
    local notes = {}
    -- groups first, so rules can find them
    local remap = {}
    for _, f in ipairs(it.folders or {}) do
        if folderExists(f.id) then
            local old = f.id
            local nid
            repeat nid = "f" .. tostring(now()) .. tostring(math.random(1000, 9999)) until not folderExists(nid)
            f.id = nid; remap[old] = nid
        end
    end
    local restoredIds = {}
    for _, f in ipairs(it.folders or {}) do
        if f.parent and remap[f.parent] then f.parent = remap[f.parent] end
        restoredIds[f.id] = true
    end
    for _, f in ipairs(it.folders or {}) do
        if f.parent and not restoredIds[f.parent] and not folderExists(f.parent) then
            f.parent = nil
            notes[#notes + 1] = "'" .. tostring(f.name) .. "' is back at the top level (its parent group is gone)"
        end
        ns.folders[#ns.folders + 1] = f
    end
    -- rules: keep each uid unless a live rule already has it
    local live = {}
    for _, r in ipairs(ns.rules or {}) do if type(r.uid) == "string" then live[r.uid] = true end end
    local uidMap = {}
    for _, r in ipairs(it.rules or {}) do
        if type(r.uid) == "string" and live[r.uid] and ns.NewUID then
            local nu = ns.NewUID()
            uidMap[r.uid] = nu; r.uid = nu
        end
    end
    local movedToTop = 0
    for _, r in ipairs(it.rules or {}) do
        if r.parentUid and uidMap[r.parentUid] then r.parentUid = uidMap[r.parentUid] end
        if r.folder and remap[r.folder] then r.folder = remap[r.folder] end
        if r.folder and not folderExists(r.folder) then
            r.folder = nil
            if not r.parentUid then movedToTop = movedToTop + 1 end
        end
        if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end
        ns.rules[#ns.rules + 1] = r
    end
    if movedToTop > 0 then notes[#notes + 1] = movedToTop .. " rule(s) back at the top level (their group is gone)" end
    for _, r in ipairs(it.rules or {}) do if ns.RefreshVisual then pcall(ns.RefreshVisual, r) end end
    -- a group deleted on its own: what was moved up and is still there goes back in
    if it.kind == "group" and it.folders and it.folders[1] then
        local g, from = it.folders[1], it.origParent
        local ru, fo = {}, {}
        for _, u in ipairs(it.movedRules or {}) do ru[u] = true end
        for _, x in ipairs(it.movedFolders or {}) do fo[x] = true end
        for _, r in ipairs(ns.rules) do if type(r.uid) == "string" and ru[r.uid] and r.folder == from then r.folder = g.id end end
        for _, f in ipairs(ns.folders) do if fo[f.id] and f.parent == from and f ~= g then f.parent = g.id end end
    end
    table.remove(b.items, idx)
    if ns.MarkDirty then ns.MarkDirty() end
    return true, table.concat(notes, "; ")
end

function ns.RecycleDeleteNow(id)
    local it, idx, b = findItem(id)
    if not it then return false end
    table.remove(b.items, idx)
    return true
end

function ns.RecycleEmpty()
    local b = ns.RecycleDB()
    if not b then return 0 end
    local n = #b.items
    b.items = {}
    return n
end

-- Removes for good what has been in the bin longer than the chosen time. Cheap; safe to call often. Returns how many went.
function ns.RecyclePurge(at)
    local b = ns.RecycleDB()
    if not b then return 0 end
    local limit = (at or now()) - ns.RecycleKeepHours() * 3600
    local n = 0
    for i = #b.items, 1, -1 do
        local d = b.items[i].deletedAt
        if type(d) ~= "number" or d <= limit then table.remove(b.items, i); n = n + 1 end
    end
    return n
end

-- For the page: newest first, with what each holds and the hours left before it goes for good.
function ns.RecycleItems(at)
    local b = ns.RecycleDB()
    local out = {}
    if not b then return out end
    local t, keep = at or now(), ns.RecycleKeepHours() * 3600
    for _, it in ipairs(b.items) do
        local nr = 0
        for _, r in ipairs(it.rules or {}) do if not r.parentUid then nr = nr + 1 end end
        out[#out + 1] = { id = it.id, kind = it.kind, name = it.name, rules = nr, groups = #(it.folders or {}),
            deletedAt = it.deletedAt, hoursLeft = math.max(0, ((it.deletedAt or 0) + keep - t) / 3600) }
    end
    table.sort(out, function(a, c) return (a.deletedAt or 0) > (c.deletedAt or 0) end)
    return out
end

-- Purge at login and every 30 minutes (long sessions cross the keep time without a reload).
if CreateFrame then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        pcall(ns.RecyclePurge)
        if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1800, function() pcall(ns.RecyclePurge) end) end
    end)
end
