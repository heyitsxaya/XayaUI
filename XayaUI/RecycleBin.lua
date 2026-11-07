-- XayaUI: RecycleBin -- deleting a rule or a group moves it here instead of throwing it away (GitHub #88).
--
-- What goes in (each delete is ONE bin item, restored as a whole):
--   * a rule, with its cues and conditions (the rows whose parentUid chain leads to it);
--   * a group deleted on its own: only the group; its rules and nested groups move up one level as before, and Restore moves the
--     ones that are still where they were moved back into it;
--   * a group deleted with its contents: the group, every group nested in it and every rule inside them.
--   * FA-11 (Xaya, her words: "Recycle Bin, no prompt (Recommended)"): a cue, a condition or a trigger removed with the red X in the rule
--     editor. Restore puts it back into its rule, at the place it had (a cue also gets back its place in the conditions that played it).
--     Its rule has to be there: while the rule itself is in the bin, Restore says so and keeps the item.
-- Drafts and backups do not go here.
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
-- FA-14 (core 0.6.67; Xaya: "Ask first (Recommended)"): how many items a keep time of h hours would remove for good right now
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

-- (P4) one item into the bin; returns it. The kinds' own deletes (XayaUI Rules: XayaUI_Rules/RuleBin.lua) put their items in here.
local function addItem(item)
    local b = ns.RecycleDB()
    if not b then return nil end
    item.id = b.nextId
    b.nextId = b.nextId + 1
    item.deletedAt = now()
    b.items[#b.items + 1] = item
    local R = ns.Service and ns.Service("rules"); if R then R.MarkDirty() end   -- (P4) XayaUI Rules redraws, when on
    return item
end

ns.RecycleAdd = addItem

local function findItem(id)
    local b = ns.RecycleDB()
    if not b then return nil end
    for i, it in ipairs(b.items) do if it.id == id then return it, i, b end end
end


-- (core 0.6.74; plan 6.3) the line the page shows for an item whose kind no module registered (its module is switched off): the item
-- stays in the bin as it is
local function unknownText(it) return "(" .. tostring(it and it.kind) .. ": module not loaded)" end
ns.RecycleUnknownText = unknownText

-- what the page says an item is, from its registered kind
function ns.RecycleDescribe(it)
    local k = type(it) == "table" and ns.BinKind and ns.BinKind(it.kind)
    if not (k and type(k.describe) == "function") then return unknownText(it) end
    local ok, txt = pcall(k.describe, it)
    if ok and type(txt) == "string" then return txt end
    return unknownText(it)
end

-- Puts an item back through its registered kind. Returns ok, note. An item whose kind is not registered stays where it is.
function ns.RecycleRestore(id)
    local it, _, b = findItem(id)
    if not it then return false, "that item is no longer in the Recycle Bin" end
    local k = ns.BinKind and ns.BinKind(it.kind)
    if not k then return false, unknownText(it) end
    local okC, ok, note = pcall(k.restore, it)
    if not okC then
        local h = geterrorhandler and geterrorhandler(); if h then h(ok) end
        return false, "it could not be restored (an error was recorded; /xui bug)"
    end
    if ok then
        for i, x in ipairs(b.items) do if x == it then table.remove(b.items, i); break end end
        local R = ns.Service and ns.Service("rules"); if R then R.MarkDirty() end   -- (P4) XayaUI Rules redraws, when on
    end
    return ok and true or false, note
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
        out[#out + 1] = { id = it.id, kind = it.kind, name = it.name, rules = nr, groups = #(it.folders or {}), owner = it.owner,
            deletedAt = it.deletedAt, hoursLeft = math.max(0, ((it.deletedAt or 0) + keep - t) / 3600), what = ns.RecycleDescribe(it) }
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
