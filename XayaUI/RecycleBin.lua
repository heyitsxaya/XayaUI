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
            -- audit D55 (core 0.6.67): every moved rule is recorded, so Restore brings it back; a rule with no uid yet (no cue or
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

-------------------------------------------------------------------------------
-- FA-11: a cue, a condition or a trigger removed with the red X
-------------------------------------------------------------------------------
local function liveRuleByUid(uid)
    if type(uid) ~= "string" then return nil end
    for _, r in ipairs(ns.rules or {}) do if r.uid == uid and not r.parentUid then return r end end
end
local function isCueRow(r) return r.isCue and true or false end

-- A cue or a condition (a rule row with a parentUid): taken out of the rules into one bin item. Returns the item, or nil (the caller then
-- removes it the old way).
function ns.RecycleChild(child)
    if type(child) ~= "table" or type(child.parentUid) ~= "string" or not ns.rules then return nil end
    local parent = liveRuleByUid(child.parentUid)
    local pos, k = nil, 0   -- its place among the rule's cues (or conditions)
    for _, r in ipairs(ns.rules) do
        if r.parentUid == child.parentUid and isCueRow(r) == isCueRow(child) then
            k = k + 1
            if r == child then pos = k end
        end
    end
    if not pos then return nil end
    local refs = {}
    if child.isCue and parent and child.cueKey ~= nil then
        -- the conditions that play this cue: remembered (by uid) so Restore links it again, then unlinked as ns.DeleteCue does
        for _, r in ipairs(ns.rules) do
            if r.parentUid == parent.uid and not r.isCue then
                local at, mod
                if type(r.thenCues) == "table" then for i, key in ipairs(r.thenCues) do if key == child.cueKey then at = i end end end
                if type(r.thenMods) == "table" then mod = r.thenMods[child.cueKey] end
                if at or mod ~= nil then
                    if type(r.uid) ~= "string" and ns.NewUID then r.uid = ns.NewUID() end
                    refs[#refs + 1] = { cond = r.uid, at = at, mod = (type(mod) == "table" and ns.Copy) and ns.Copy(mod) or mod }
                    if at then
                        for i = #r.thenCues, 1, -1 do if r.thenCues[i] == child.cueKey then table.remove(r.thenCues, i) end end
                        if #r.thenCues == 0 then r.thenCues = nil end
                    end
                    if mod ~= nil then r.thenMods[child.cueKey] = nil; if next(r.thenMods) == nil then r.thenMods = nil end end
                end
            end
        end
    end
    local taken = takeRules({ child })
    if #taken == 0 then return nil end
    local name
    if child.isCue then name = (ns.CueLabel and parent and ns.CueLabel(child)) or child.cueName or "Cue"
    else name = (type(child.name) == "string" and child.name ~= "") and child.name or "Condition" end
    return addItem({ kind = child.isCue and "cue" or "condition", name = tostring(name), rules = taken, parentUid = child.parentUid,
        owner = parent and ruleName(parent) or nil, pos = pos, refs = refs })
end

-- A trigger of a rule: tok "cd" / "buff" (the built-in Cooldown / Buff / Aura trigger: its fields) or "x" with row j (an additional
-- trigger: a copy of the row). Call it BEFORE removing the trigger; it only stores the copy. Returns the item.
local TRIGGER_FIELDS = {
    cd = { "useCooldown", "spellID", "maxCharges", "cdState", "countGCD", "countLOC", "cdTimeOp", "cdTimeSec", "cdChargeOp", "cdChargeVal", "exactSpell", "cdName" },
    buff = { "useBuff", "buffID", "buffAlt", "buffState", "buffTimeOp", "buffTimeSec", "buffName" },
}
function ns.RecycleTrigger(rule, tok, j)
    if type(rule) ~= "table" or not ns.TriggerSequence or not ns.Copy then return nil end
    local seq = ns.TriggerSequence(rule)
    local seqPos, copy, label, refs, trigMode
    if tok == "x" then
        local row = type(rule.extra) == "table" and type(rule.extra.list) == "table" and rule.extra.list[j]
        if type(row) ~= "table" then return nil end
        local seen = 0
        for i, tk in ipairs(seq) do if tk == "x" then seen = seen + 1; if seen == j then seqPos = i; break end end end
        copy = ns.Copy(row)
        -- the condition rows that read this trigger lose it when it is removed (ns.RemapOutcomeRefs): remembered so Restore points them back
        refs = {}
        for _, o in ipairs(ns.OutcomesOf and ns.OutcomesOf(rule) or {}) do
            if type(o.when) == "table" and type(o.when.list) == "table" then
                for ti, t in ipairs(o.when.list) do
                    local ref = type(t.ref) == "string" and t.ref or ""
                    local pre, n, suf = ref:match("^(n?:?x)(%d+)(%a?)$")
                    if n and tonumber(n) == j and (pre == "x" or pre == "n:x") then
                        if type(o.uid) ~= "string" and ns.NewUID then o.uid = ns.NewUID() end
                        refs[#refs + 1] = { cond = o.uid, term = ti, pre = pre, suf = suf }
                    end
                end
            end
        end
        trigMode = (rule.trigMode == "x" .. j) or nil
        local def = ns.TRIGGER_TYPES and ns.TRIGGER_TYPES[row.type]
        label = (type(row.name) == "string" and row.name ~= "") and row.name or (def and def.label) or "Trigger"
    elseif TRIGGER_FIELDS[tok] then
        for i, tk in ipairs(seq) do if tk == tok then seqPos = i end end
        if not seqPos then return nil end   -- not in use: nothing to keep
        copy = {}
        for _, k in ipairs(TRIGGER_FIELDS[tok]) do local v = rule[k]; copy[k] = (type(v) == "table") and ns.Copy(v) or v end
        label = (tok == "cd") and (rule.cdName or "Cooldown") or (rule.buffName or "Buff / Aura")
    else
        return nil
    end
    if type(rule.uid) ~= "string" and ns.NewUID then rule.uid = ns.NewUID() end
    if type(rule.uid) ~= "string" then return nil end
    return addItem({ kind = "trigger", name = tostring(label), owner = ruleName(rule), ruleUid = rule.uid, tok = tok, j = j,
        seqPos = seqPos or (#seq + 1), trigger = copy, refs = refs, trigMode = trigMode, rules = {} })
end

-- Restore of the three kinds above. Returns ok, note.
local function restoreChild(it)
    local parent = liveRuleByUid(it.parentUid)
    if not parent then return false, "its rule '" .. tostring(it.owner or "?") .. "' is not in your rules (restore that rule first)" end
    local live = {}
    for _, r in ipairs(ns.rules) do if type(r.uid) == "string" then live[r.uid] = true end end
    local wantCue = it.kind == "cue"
    local remapKey
    for _, r in ipairs(it.rules or {}) do
        if type(r.uid) == "string" and live[r.uid] and ns.NewUID then r.uid = ns.NewUID() end
        r.folder = parent.folder
        if r.isCue and r.cueKey ~= nil and ns.CueKey then   -- a cue added since then may use its key: take a free one
            for _, c in ipairs(ns.rules) do
                if c.parentUid == parent.uid and c.isCue and c.cueKey == r.cueKey then local nk = ns.CueKey(parent); remapKey = { r.cueKey, nk }; r.cueKey = nk; break end
            end
        end
        if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end
    end
    -- the place it had: before the sibling now at its position, else after the rule's last row
    local at, k, last = nil, 0, nil
    for i, r in ipairs(ns.rules) do
        if r == parent or r.parentUid == parent.uid then last = i end
        if r.parentUid == parent.uid and isCueRow(r) == wantCue then
            k = k + 1
            if k == it.pos and not at then at = i end
        end
    end
    at = at or ((last or #ns.rules) + 1)
    for n, r in ipairs(it.rules or {}) do table.insert(ns.rules, at + n - 1, r) end
    -- a cue: link it again in the conditions that played it (those still there)
    local key = it.rules and it.rules[1] and it.rules[1].cueKey
    local relinked = 0
    for _, ref in ipairs(it.refs or {}) do
        for _, c in ipairs(ns.rules) do
            if c.uid == ref.cond and c.parentUid == parent.uid and not c.isCue and key ~= nil then
                if ref.at then
                    c.thenCues = type(c.thenCues) == "table" and c.thenCues or {}
                    table.insert(c.thenCues, math.min(ref.at, #c.thenCues + 1), key)
                end
                if ref.mod ~= nil then c.thenMods = type(c.thenMods) == "table" and c.thenMods or {}; c.thenMods[key] = ref.mod end
                relinked = relinked + 1
                break
            end
        end
    end
    for _, r in ipairs(it.rules or {}) do if ns.RefreshVisual then pcall(ns.RefreshVisual, r) end end
    local notes = {}
    if remapKey then notes[#notes + 1] = "it got a new cue key" end
    if #(it.refs or {}) > relinked then notes[#notes + 1] = (#it.refs - relinked) .. " condition(s) that played it are gone" end
    return true, table.concat(notes, "; ")
end
local function restoreTrigger(it)
    local rule = liveRuleByUid(it.ruleUid)
    if not rule then return false, "its rule '" .. tostring(it.owner or "?") .. "' is not in your rules (restore that rule first)" end
    local seq = ns.TriggerSequence and ns.TriggerSequence(rule) or {}
    if it.tok == "x" then
        rule.extra = type(rule.extra) == "table" and rule.extra or {}
        rule.extra.list = type(rule.extra.list) == "table" and rule.extra.list or {}
        local list = rule.extra.list
        if #list >= 12 then return false, "its rule already has 12 additional triggers (remove one first)" end
        local j = math.max(1, math.min(tonumber(it.j) or (#list + 1), #list + 1))
        -- the k-th "x" in the trigger order is row k, so the new "x" goes just before the one that is row j now (it becomes row j + 1);
        -- with no row j yet, at its old place but after every additional trigger already there
        local at, seen, lastX = nil, 0, 0
        for i, tk in ipairs(seq) do
            if tk == "x" then seen = seen + 1; lastX = i; if seen == j and not at then at = i end end
        end
        if not at then at = math.max(math.min(tonumber(it.seqPos) or (#seq + 1), #seq + 1), lastX + 1) end
        if ns.RemapOutcomeRefs then ns.RemapOutcomeRefs(rule, function(n) if n >= j then return "x" .. (n + 1) end return "x" .. n end) end
        table.insert(list, j, ns.Copy(it.trigger))
        table.insert(seq, at, "x")
        rule.trigOrder = seq
        -- the condition rows that read it (still there and still empty) and the "activated by" choice point at it again
        for _, ref in ipairs(it.refs or {}) do
            for _, o in ipairs(ns.OutcomesOf and ns.OutcomesOf(rule) or {}) do
                if o.uid == ref.cond and type(o.when) == "table" and type(o.when.list) == "table" then
                    local t = o.when.list[ref.term]
                    if t and t.ref == nil then t.ref = tostring(ref.pre) .. j .. tostring(ref.suf or "") end
                    break
                end
            end
        end
        if it.trigMode and rule.trigMode == nil then rule.trigMode = "x" .. j end
    else
        local used = (it.tok == "cd") and ns.CooldownUsed or ns.BuffUsed
        if used and used(rule) then return false, "its rule already has a " .. ((it.tok == "cd") and "Cooldown" or "Buff / Aura") .. " trigger (remove it first)" end
        for _, k in ipairs(TRIGGER_FIELDS[it.tok] or {}) do local v = it.trigger[k]; rule[k] = (type(v) == "table") and ns.Copy(v) or v end
        if it.tok == "cd" then rule.useCooldown = true else rule.useBuff = true end
        table.insert(seq, math.max(1, math.min(tonumber(it.seqPos) or (#seq + 1), #seq + 1)), it.tok)
        rule.trigOrder = seq
    end
    if ns.RefreshVisual then pcall(ns.RefreshVisual, rule) end
    return true, ""
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
-- (core 0.6.74) the restore of the kinds "rule", "group" and "groupAll" (the bin item holds rules and groups). Returns ok, note.
local function restoreRules(it)
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
    return true, table.concat(notes, "; ")
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
        if ns.MarkDirty then ns.MarkDirty() end
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

-------------------------------------------------------------------------------
-- (core 0.6.74; plan 6.3) the rule kinds, registered by the rule-tracking side through the Platform's ns.RegisterBinKind (Modules.lua).
-- This block moves to Core with the rules in P4; the bin above keeps the storage, the keep times and the page. The page's wording for
-- each kind is what Options.lua showed before (moved here unchanged).
-------------------------------------------------------------------------------
local function topRules(it) local n = 0; for _, r in ipairs(it.rules or {}) do if not r.parentUid then n = n + 1 end end; return n end
local CHILD_WORD = { cue = "Cue", condition = "Condition", trigger = "Trigger" }   -- FA-11: removed with the red X in a rule
local function childLine(it) return CHILD_WORD[it.kind] .. " of the rule '" .. tostring(it.owner or "?") .. "'" end
if ns.RegisterBinKind then
    ns.RegisterBinKind({ kind = "rule", label = "Rule", describe = function() return "Rule" end, restore = restoreRules })
    ns.RegisterBinKind({ kind = "group", label = "Group", describe = function() return "Group (its contents had moved up one level)" end, restore = restoreRules })
    ns.RegisterBinKind({ kind = "groupAll", label = "Group with its contents",
        describe = function(it) return ("Group with its contents: %d rule(s), %d group(s)"):format(topRules(it), #(it.folders or {})) end, restore = restoreRules })
    ns.RegisterBinKind({ kind = "cue", label = "Cue", describe = childLine, restore = restoreChild })
    ns.RegisterBinKind({ kind = "condition", label = "Condition", describe = childLine, restore = restoreChild })
    ns.RegisterBinKind({ kind = "trigger", label = "Trigger", describe = childLine, restore = restoreTrigger })
end
