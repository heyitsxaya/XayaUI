-------------------------------------------------------------------------------
-- RuleShare.lua : the rules side of sharing (P4, docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.2): the rules snapshots, the
-- share kind "rules" (XUI1) with its "wait until combat ends" step, the profile part "Rules and groups" and the rule backups. Moved
-- unchanged from XayaUI/Share.lua (core 0.6.75); the codec, the kind registry and Share.AfterCombat stay in the Platform's Share.lua,
-- and this file registers its kind there (Share.RegisterKind). No string format changed: every string shared before still imports.
-------------------------------------------------------------------------------
local addonName, ns = ...; ns = XayaUI_NS or ns   -- the Platform's namespace (XayaUI/Core.lua)
local function QoLBoxes() local s = ns.Service and ns.Service("statsText"); return s and s.Boxes() end   -- (P5) XayaUI QoL's stats-text boxes (XayaUI_QoL/StatsText.lua), nil while it is off
local CoreS, PlatS = ns.Settings("core"), ns.Settings("platform")   -- (P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
local Share = ns.Share   -- (the Platform's Share.lua)
local MAX_DEPTH = 16     -- (the same nesting limit as the Platform's codec)

-------------------------------------------------------------------------------
-- Snapshot / encode / decode
-------------------------------------------------------------------------------
-- include = { rules = bool, bars = bool, qol = bool }  (nil = everything)
function ns.Share_SnapshotAll(include, name)
    include = include or { rules = true, bars = true, qol = true }
    local snap = { v = 1, name = name or "", addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name or addonName, "Version")) or "" }
    if include.rules then
        snap.rules = ns.Copy(ns.rules)
        snap.folders = ns.Copy(ns.folders)
    end
    -- Buff bars and QoL elements are switched off for now (their files are not loaded): nothing of them is exported
    if include.bars and ns.BarsOn then
        snap.bars = ns.Copy(ns.bars)
        snap.barGroup = ns.Copy(CoreS.barGroup)
    end
    if include.qol and ns.QoLOn then snap.qol = ns.Copy(QoLBoxes()) end
    return snap
end

-- One rule (plus its outcomes, which are part of it). No folders: the rule lands at the top level when imported.
function ns.Share_SnapshotRule(rule, name)
    local snap = { v = 1, name = name or "", addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name or addonName, "Version")) or "" }
    local list = { ns.Copy(rule) }
    if ns.OutcomesOf and not rule.parentUid then
        for _, o in ipairs(ns.OutcomesOf(rule)) do list[#list + 1] = ns.Copy(o) end
    end
    for _, r in ipairs(list) do r.folder = nil end
    snap.rules = list
    snap.folders = {}
    return snap
end

-- One group with every group nested in it, every rule inside them, and those rules' cues / conditions (the outcomes link to their rule
-- by uid, so they come along even when they carry no folder of their own). The top group's parent is dropped so it lands inside
-- the import wrapper; nested groups keep their parents.
function ns.Share_SnapshotGroup(fold, name)
    local snap = { v = 1, name = name or tostring(fold and fold.name or ""), addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name or addonName, "Version")) or "" }
    local ids, order, stack = { [fold.id] = true }, { fold }, { fold.id }
    while #stack > 0 do
        local cur = table.remove(stack)
        for _, f in ipairs(ns.folders or {}) do
            if f.parent == cur and not ids[f.id] then ids[f.id] = true; order[#order + 1] = f; stack[#stack + 1] = f.id end
        end
    end
    snap.folders = {}
    for _, f in ipairs(order) do
        local c = ns.Copy(f)
        if f == fold then c.parent = nil end
        snap.folders[#snap.folders + 1] = c
    end
    local have, rules = {}, {}
    for _, r in ipairs(ns.rules or {}) do
        if r.folder and ids[r.folder] then have[r] = true; rules[#rules + 1] = ns.Copy(r) end
    end
    if ns.OutcomesOf then
        for _, r in ipairs(ns.rules or {}) do
            if have[r] and not r.parentUid then
                for _, o in ipairs(ns.OutcomesOf(r)) do
                    if not have[o] then have[o] = true; rules[#rules + 1] = ns.Copy(o) end
                end
            end
        end
    end
    snap.rules = rules
    return snap
end

-- Plain-language description of a snapshot (for the import preview).
function ns.Share_DescribeRules(snap)
    local function n(t) return type(t) == "table" and #t or 0 end
    local files = 0
    for _, r in ipairs(type(snap.rules) == "table" and snap.rules or {}) do
        if type(r) == "table" and type(r.sound) == "table" and r.sound.source == "file" and r.sound.enabled then files = files + 1 end
    end
    local s = ("%d rule(s), %d folder(s), %d buff bar(s), %d QoL box(es)"):format(n(snap.rules), n(snap.folders), n(snap.bars), n(snap.qol))
    if files > 0 then
        s = s .. ("\n|cffffaa00%d rule(s) use a sound from a local file. Your friend must have that same file, or pick another sound.|r"):format(files)
    end
    return s
end

-------------------------------------------------------------------------------
-- Apply
-------------------------------------------------------------------------------
local function IsTbl(t) return type(t) == "table" end

local function NewId(used)
    local id
    repeat id = "f" .. tostring(time()) .. tostring(math.random(1000, 9999)) until not used[id]
    used[id] = true
    return id
end

-- mode: "add" (append to what you have) | "replace" (swap the included parts out)
function ns.Share_ApplyRules(snap, mode)
    local counts = { rules = 0, folders = 0, bars = 0, qol = 0 }
    local replace = (mode == "replace")

    if IsTbl(snap.rules) then
        if replace then
            for _, r in ipairs(ns.rules) do if ns.EndRule then pcall(ns.EndRule, r) end; ns.DropVisual(r) end   -- (audit D56)
            wipe(ns.rules); wipe(ns.folders)
        end
        local used, map = {}, {}
        for _, f in ipairs(ns.folders) do used[f.id] = true end
        -- Everything imported (not a replace) goes into ONE new top-level folder of its own, so it never mixes with your rules and can be
        -- moved or deleted as a unit. Imported groups keep all their settings and sit inside it; ungrouped rules go straight into it.
        local wrap
        if not replace and #snap.rules > 0 then
            local nm = (type(snap.name) == "string" and snap.name ~= "") and snap.name or "Import"
            wrap = { id = NewId(used), name = ("Imported: %s (%s)"):format(nm, date and date("%Y-%m-%d %H:%M") or ""),
                origin = { by = ns.CharacterKey and ns.CharacterKey() or nil, how = "imported", at = time and time() or nil } }
            ns.folders[#ns.folders + 1] = wrap
            counts.folders = counts.folders + 1
        end
        local added, keptDefault = {}, {}
        for _, f in ipairs(IsTbl(snap.folders) and snap.folders or {}) do
            if IsTbl(f) and type(f.id) == "string" then
                local nf = ns.Copy(f)                      -- keep the group's own settings (container type, overrides, ...)
                -- A built-in category flag must not be duplicated by an "add" import. A replace (Load a backup) swaps every folder out,
                -- so it keeps the flag of a top-level category once each (audit D40, core 0.6.67): without it Display Cues / Sound Cues
                -- became plain folders and every rule's kind changed (EnsureDefaultFolders does not run again once its version is set).
                local d = nf.default
                nf.default = nil
                if replace and type(d) == "string" and not keptDefault[d] and f.parent == nil and ns.DefaultFolderInfo and ns.DefaultFolderInfo(d) then
                    nf.default, keptDefault[d] = d, true
                end
                -- who made it stays the exporter's record (plain text only); without one it reads "imported"
                nf.origin = ns.CleanOrigin and ns.CleanOrigin(f.origin) or nil
                if nf.origin then nf.origin.imported = time and time() or true else nf.origin = { how = "imported", at = time and time() or nil } end
                nf.name = type(f.name) == "string" and f.name or "Folder"
                nf.id = NewId(used)   -- always a fresh id of the usual form (the tree and its menus recognise groups by that form)
                map[f.id] = nf.id
                ns.folders[#ns.folders + 1] = nf
                added[#added + 1] = { nf = nf, oldParent = type(f.parent) == "string" and f.parent or nil }
                counts.folders = counts.folders + 1
            end
        end
        for _, a in ipairs(added) do a.nf.parent = (a.oldParent and map[a.oldParent]) or (wrap and wrap.id) or nil end
        -- a group that follows another group (B, Rules 0.6.82): re-pointed to that group's new id; one that followed a group not in
        -- the import is placed from the screen (or its parent group) instead, never from an unrelated group that has the old id here
        for _, a in ipairs(added) do
            if a.nf.cGroup ~= nil then
                a.nf.cGroup = map[a.nf.cGroup]
                if a.nf.cGroup == nil and a.nf.cRel == "group" then a.nf.cRel = nil end
            end
        end
        -- outcomes link to their parent by uid: give imported uids that already exist here a fresh value, and re-point the links
        local haveUid, uidMap = {}, {}
        for _, r in ipairs(ns.rules) do if type(r.uid) == "string" then haveUid[r.uid] = true end end
        if ns.NewUID then
            for _, r in ipairs(snap.rules) do
                if IsTbl(r) and type(r.uid) == "string" and haveUid[r.uid] then uidMap[r.uid] = ns.NewUID(); haveUid[uidMap[r.uid]] = true end
            end
            for _, r in ipairs(snap.rules) do
                if IsTbl(r) then
                    if type(r.uid) == "string" and uidMap[r.uid] then r.uid = uidMap[r.uid] end
                    if type(r.parentUid) == "string" and uidMap[r.parentUid] then r.parentUid = uidMap[r.parentUid] end
                end
            end
        end
        for _, r in ipairs(snap.rules) do
            if IsTbl(r) then
                ns.NormalizeRule(r)
                if r.folder ~= nil then r.folder = map[r.folder] end
                if r.folder == nil and wrap and not r.isCue then r.folder = wrap.id end
                r.spellID = tonumber(r.spellID) or 0
                r.buffID = tonumber(r.buffID) or 0
                ns.rules[#ns.rules + 1] = r
                counts.rules = counts.rules + 1
            end
        end
    end

    if IsTbl(snap.bars) then
        if replace then
            for _, b in ipairs(ns.bars) do if ns.Bars_Drop then ns.Bars_Drop(b) end end
            wipe(ns.bars)
        end
        for _, b in ipairs(snap.bars) do
            if IsTbl(b) then
                ns.Merge(b, ns.BAR_DEFAULTS)
                b.buffID = tonumber(b.buffID) or 0
                ns.bars[#ns.bars + 1] = b
                counts.bars = counts.bars + 1
            end
        end
        if replace and IsTbl(snap.barGroup) then
            wipe(CoreS.barGroup)
            for k, v in pairs(snap.barGroup) do CoreS.barGroup[k] = v end
            ns.Merge(CoreS.barGroup, ns.BAR_GROUP_DEFAULTS)
        end
    end

    if IsTbl(snap.qol) and QoLBoxes() then   -- (P5) the stats-text boxes are XayaUI QoL's: none while it is off
        if replace then
            for _, b in ipairs(QoLBoxes()) do if ns.QoL_Drop then ns.QoL_Drop(b) end end
            wipe(QoLBoxes())
        end
        for _, b in ipairs(snap.qol) do
            if IsTbl(b) then
                ns.Merge(b, ns.Service("statsText").DEFAULTS)
                QoLBoxes()[#QoLBoxes() + 1] = b
                counts.qol = counts.qol + 1
            end
        end
    end

    if ns.ClearPreview then ns.ClearPreview() end
    ns.RefreshAllVisuals()
    if ns.Bars_RefreshAll then ns.Bars_RefreshAll() end
    if ns.QoL_RefreshAll then ns.QoL_RefreshAll() end
    ns.MarkDirty()
    ns.Fire("CONFIG_CHANGED")
    return counts
end

-------------------------------------------------------------------------------
-- Kind "rules" (XUI1): one rule, a group, or several rules with their groups. The format has not changed since 0.5, so strings
-- shared before 0.6.0 still import.
-------------------------------------------------------------------------------
-- never exported: anything starting with "_" (runtime state), and how the editor had a rule or group folded open or closed
local UI_STATE = { ocCollapsed = true, collapsed = true }
local function StripLocal(t, depth)
    if type(t) ~= "table" or depth > MAX_DEPTH then return end
    for k, v in pairs(t) do
        if type(k) == "string" and (k:sub(1, 1) == "_" or (depth <= 1 and UI_STATE[k])) then t[k] = nil
        elseif type(v) == "table" then StripLocal(v, depth + 1) end
    end
end
Share.RegisterKind({
    kind = "rules", prefix = "XUI1", version = 1, label = "rules", changesSecureFrames = true,
    where = "Rules are imported with the Import button (toolbar) or under Import / Export.",
    Strip = function(snap)
        for _, r in ipairs(type(snap.rules) == "table" and snap.rules or {}) do StripLocal(r, 1) end
        for _, f in ipairs(type(snap.folders) == "table" and snap.folders or {}) do StripLocal(f, 1) end
    end,
    Check = function(snap)
        -- custom code is never taken from an import: an imported string can only ever hold settings, not something that runs
        if type(snap.rules) == "table" then
            for _, r in ipairs(snap.rules) do
                if type(r) == "table" and type(r.actions) == "table" then
                    for _, act in pairs(r.actions) do if type(act) == "table" then act.code, act.codeOn = nil, nil end end
                end
            end
        end
        return snap
    end,
    Describe = function(snap) return ns.Share_DescribeRules(snap) end,
    Apply = function(snap, mode) return ns.Share_ApplyRules(snap, mode) end,
})

-- (core 0.6.74; plan 6.1) the profile part "Rules and groups": the rules snapshot (rules, groups; buff bars and QoL boxes while their
-- files are loaded), applied with Add or Replace like a rules string. Registered by XayaUI Rules (moved here from the Platform's Share.lua in P4).
-- mode: "add" (default, today's Import window) | "replace".
if ns.RegisterProfilePart then
    ns.RegisterProfilePart({ key = "rules", label = "Rules and groups", module = addonName, order = 10, version = 1, reload = false,
        snapshot = function(name) return ns.Share_SnapshotAll({ rules = true, bars = true, qol = true }, name) end,
        check = function(part)
            local rk = Share.kinds.rules
            local okR, rr = pcall(rk.Check, part)
            if okR and type(rr) == "table" then return rr end
        end,
        strip = function(part) local rk = Share.kinds.rules; if rk and rk.Strip then rk.Strip(part) end end,
        describe = function(part) return ns.Share_DescribeRules(part) end,
        apply = function(part, mode) return ns.Share_ApplyRules(part, mode == "replace" and "replace" or "add") end,
    })
end

-------------------------------------------------------------------------------
-- Backups: copies of your rules saved inside XayaUI (CueRulesDB.profiles, the key it always had: renaming the saved key would
-- hide your backups from an older XayaUI if you went back to one). Load (add), Load (replace), show as text, delete.
-------------------------------------------------------------------------------
function ns.Backups()
    PlatS.profiles = PlatS.profiles or {}   -- (P4: through the Platform's settings view, the same key)
    return PlatS.profiles
end

function ns.Backup_Save(name, include)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "give the backup a name first" end
    local snap = ns.Share_SnapshotAll(include, name)
    local list = ns.Backups()
    for i, p in ipairs(list) do
        if p.name == name then list[i] = { name = name, data = snap }; return true, "updated" end
    end
    list[#list + 1] = { name = name, data = snap }
    return true, "saved"
end

function ns.Backup_Delete(idx) table.remove(ns.Backups(), idx) end

-------------------------------------------------------------------------------
-- (P5, docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5 step 3, risk R1) the guards around the one-time copy of the rules' settings from
-- CueRulesDB into this addon's own store (Modules.lua section 0c):
--   before: a backup of the rules and groups as they are in CueRulesDB, in Profiles > Backups (CueRulesDB.profiles, where every backup
--           lives: Load (add) / Load (replace) / show as text restore it), named "Rules before the settings move (<date>)";
--   check:  the numbers of rules, groups and buff bars must be the same on both sides (the Platform compares every copied table too).
-- Any difference: the Platform keeps this addon on CueRulesDB, takes the copy out again and tells the player once.
-------------------------------------------------------------------------------
local function Count(t) return type(t) == "table" and #t or 0 end
if ns.SettingsMigrationGuard then
    ns.SettingsMigrationGuard("core", {
        before = function(old)
            if type(old) ~= "table" or (Count(old.rules) == 0 and Count(old.folders) == 0) then return end
            local stamp = date and date("%Y-%m-%d %H:%M") or "?"
            local name = "Rules before the settings move (" .. stamp .. ")"
            local snap = { v = 1, name = name, addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name or addonName, "Version")) or "",
                rules = ns.Copy(type(old.rules) == "table" and old.rules or {}), folders = ns.Copy(type(old.folders) == "table" and old.folders or {}) }
            local list = ns.Backups()
            for i, p in ipairs(list) do if p.name == name then list[i] = { name = name, data = snap }; return end end
            list[#list + 1] = { name = name, data = snap }
        end,
        check = function(old, store)
            local diffs = {}
            for _, k in ipairs({ "rules", "folders", "bars" }) do
                local a, b = Count(old and old[k]), Count(store and store[k])
                if a ~= b then diffs[#diffs + 1] = ("%s %d vs %d"):format(k, a, b) end
            end
            if #diffs > 0 then return "counts differ: " .. table.concat(diffs, ", ") end
            return nil
        end,
    })
end
