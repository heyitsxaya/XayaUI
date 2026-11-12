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

-- What a snapshot holds, counted: { rules, folders, bars, qol, files } (files: rules that play a sound from a local file).
local function CountSnap(snap)
    local function n(t) return type(t) == "table" and #t or 0 end
    local files = 0
    for _, r in ipairs(type(snap.rules) == "table" and snap.rules or {}) do
        if type(r) == "table" and type(r.sound) == "table" and r.sound.source == "file" and r.sound.enabled then files = files + 1 end
    end
    return { rules = n(snap.rules), folders = n(snap.folders), bars = n(snap.bars), qol = n(snap.qol), files = files }
end
local function DescribeCounts(c)
    local function n(v) return tonumber(v) or 0 end
    local s = ("%d rule(s), %d folder(s), %d buff bar(s), %d QoL box(es)"):format(n(c.rules), n(c.folders), n(c.bars), n(c.qol))
    if n(c.files) > 0 then
        s = s .. ("\n|cffffaa00%d rule(s) use a sound from a local file. Your friend must have that same file, or pick another sound.|r"):format(n(c.files))
    end
    return s
end
local BackupCounts   -- (below, Backups: a backup kept as text is described from the counts saved with it, without reading the text)

-- Plain-language description of a snapshot (for the import preview, and each backup in Profiles > Backups).
function ns.Share_DescribeRules(snap)
    local c = BackupCounts and BackupCounts(snap)
    return DescribeCounts(c or CountSnap(snap))
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
--
-- (round 6; REQUEST-LOG A23 SD-55, Xaya's answer on the memory cuts: "Compact backups (7.8 -> ~2 MB)") each backup is kept as ONE text
-- instead of a copy of every rule table (a table costs at least 64 bytes and 40 a key; the same rules as text cost about their length:
-- docs/plans/MEMORY-REPORT-2026-11-11.md P-2). It is turned back into tables only when the backup is loaded or shown as export text.
-- One backup as saved:
--   name   its name, as before;
--   text   "XUIB1:" and the snapshot as text. Read back exactly: strings, whole and decimal numbers (to the last bit), true / false,
--          number and string keys, any nesting. (Not the share-string codec: that one leaves out number keys, rounds decimals to 10
--          digits and changes "|H" in text, which is right for a pasted string but would change a backup.)
--   info   the counts Profiles > Backups shows under the backup (rules, groups, buff bars, QoL boxes, local sound files), so drawing the
--          page reads no text;
--   data   an empty table. In this version it stands for the snapshot: reading a field of it reads the text, and ns.Copy (Core.lua)
--          gives a fresh full copy, which is what Load and "Show export text" use. An older XayaUI reads "data" and finds an empty
--          backup there: its page still opens and the backup shows "0 rule(s)", and loading it changes nothing. Older XayaUI versions
--          cannot read the new backups.
-- A backup is kept as text only when its text reads back exactly equal to its tables; otherwise it stays as tables, as before.
-- A backup saved by an older XayaUI ({ name, data = <tables> }) is turned into text once, at the login (BackupsToText below).
-------------------------------------------------------------------------------
local BK_PREFIX, BK_DEPTH = "XUIB1:", 64
local sbyte, ssub, sfind, sformat = string.byte, string.sub, string.find, string.format
local B_S, B_N, B_T, B_F, B_X, B_INF, B_NINF, B_NAN, B_OPEN, B_MID, B_CLOSE = sbyte("sntfxIJN{;}", 1, -1)

-- a string, number or boolean as text (nil for anything the game cannot save either: a function, a frame)
local function BkAtom(v)
    local t = type(v)
    if t == "string" then return "s" .. #v .. ":" .. v end
    if t == "number" then
        if v ~= v then return "N" end
        if v == math.huge then return "I" end
        if v == -math.huge then return "J" end
        local s = sformat("%.15g", v)
        if tonumber(s) ~= v then s = sformat("%.17g", v) end   -- (17 digits give back every double exactly)
        return "n" .. s .. ","
    end
    if t == "boolean" then return v and "t" or "f" end
end
-- a table: "{" its list part (1, 2, 3 ... up to the first gap) ";" its other keys, each as key then value "}"
local function BkEnc(v, out, depth)
    if type(v) ~= "table" then
        local a = BkAtom(v)
        if a then out[#out + 1] = a end
        return a ~= nil
    end
    if depth > BK_DEPTH then error("nested too deeply", 0) end
    out[#out + 1] = "{"
    local n = 0
    while rawget(v, n + 1) ~= nil do
        n = n + 1
        if not BkEnc(rawget(v, n), out, depth + 1) then out[#out + 1] = "x" end
    end
    out[#out + 1] = ";"
    for k, x in next, v do
        if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
            local ka = BkAtom(k)
            if ka then
                local at = #out + 1
                out[at] = ka
                if not BkEnc(x, out, depth + 1) then out[at] = nil end
            end
        end
    end
    out[#out + 1] = "}"
    return true
end
local function BkDec(s, pos, depth)
    local c = sbyte(s, pos)
    if c == B_S then
        local colon = sfind(s, ":", pos + 1, true)
        local len = colon and tonumber(ssub(s, pos + 1, colon - 1))
        if not len or colon + len > #s then error("damaged", 0) end
        return ssub(s, colon + 1, colon + len), colon + len + 1
    elseif c == B_N then
        local comma = sfind(s, ",", pos + 1, true)
        local v = comma and tonumber(ssub(s, pos + 1, comma - 1))
        if not v then error("damaged", 0) end
        return v, comma + 1
    elseif c == B_T then return true, pos + 1
    elseif c == B_F then return false, pos + 1
    elseif c == B_INF then return math.huge, pos + 1
    elseif c == B_NINF then return -math.huge, pos + 1
    elseif c == B_NAN then return 0 / 0, pos + 1
    elseif c == B_OPEN then
        if depth > BK_DEPTH then error("damaged", 0) end
        local t, i = {}, 0
        pos = pos + 1
        c = sbyte(s, pos)
        while c ~= B_MID do
            if c == nil then error("damaged", 0) end
            i = i + 1
            if c == B_X then pos = pos + 1 else t[i], pos = BkDec(s, pos, depth + 1) end
            c = sbyte(s, pos)
        end
        pos = pos + 1
        c = sbyte(s, pos)
        while c ~= B_CLOSE do
            if c == nil then error("damaged", 0) end
            local k
            k, pos = BkDec(s, pos, depth + 1)
            if type(k) == "table" or k ~= k then error("damaged", 0) end
            t[k], pos = BkDec(s, pos, depth + 1)
            c = sbyte(s, pos)
        end
        return t, pos + 1
    end
    error("damaged", 0)
end
local function BkWrite(snap)
    local out = { BK_PREFIX }
    if not pcall(BkEnc, snap, out, 0) then return nil end
    return table.concat(out)
end
local function BkRead(text)
    if type(text) ~= "string" or ssub(text, 1, #BK_PREFIX) ~= BK_PREFIX then return nil end
    local ok, v, pos = pcall(BkDec, text, #BK_PREFIX + 1, 0)
    if ok and type(v) == "table" and pos == #text + 1 then return v end
end
-- exactly equal: the same keys holding the same values, all the way down
local function Same(a, b, depth)
    if a == b then return true end
    local t = type(a)
    if t ~= type(b) then return false end
    if t == "number" then return a ~= a and b ~= b end
    if t ~= "table" or depth > BK_DEPTH then return false end
    for k, v in next, a do if not Same(v, rawget(b, k), depth + 1) then return false end end
    for k in next, b do if rawget(a, k) == nil then return false end end
    return true
end

-- the "data" stand-in of a backup kept as text (see above)
local STAND_IN = {}
-- (both weak both ways: a backup is held by the saved list alone, so a deleted one and its text are let go at the next collection)
local backupOf = setmetatable({}, { __mode = "kv" })   -- stand-in -> its backup
local lastRead = setmetatable({}, { __mode = "kv" })   -- backup -> its snapshot as last read for a field (let go at the next collection once unused)
local function ReadBackup(e, fresh)
    local snap = not fresh and lastRead[e]
    if snap then return snap end
    snap = BkRead(rawget(e, "text"))
    if not snap then
        ns.Print(("the backup '%s' could not be read (its saved text is damaged). Nothing was changed."):format(tostring(rawget(e, "name"))))
        snap = {}
    end
    if not fresh then lastRead[e] = snap end
    return snap
end
STAND_IN.__index = function(d, k) local e = backupOf[d]; return e and ReadBackup(e)[k] end
STAND_IN.__xuiCopy = function(d) local e = backupOf[d]; return e and ReadBackup(e, true) or {} end
BackupCounts = function(snap)
    local e = type(snap) == "table" and getmetatable(snap) == STAND_IN and backupOf[snap]
    local info = e and rawget(e, "info")
    return type(info) == "table" and info or nil
end
-- (every session) a backup kept as text gets its stand-in; one kept as tables is left as it is
local function Wire(e)
    if type(e) ~= "table" or type(rawget(e, "text")) ~= "string" then return end
    local d = rawget(e, "data")
    if type(d) == "table" and backupOf[d] == e then return end
    if type(d) ~= "table" or (getmetatable(d) == nil and next(d) ~= nil) then return end   -- (tables in "data": kept as tables)
    if getmetatable(d) == nil then setmetatable(d, STAND_IN) end
    if getmetatable(d) == STAND_IN then backupOf[d] = e end
end
-- keep snap in backup e as one text when it reads back exactly; otherwise as tables (as before). Returns e.
local function KeepAsText(e, snap)
    local text = BkWrite(snap)
    local back = text and BkRead(text)
    if back and Same(snap, back, 0) then
        e.text, e.info, e.data = text, CountSnap(snap), {}
        Wire(e)
    else
        e.text, e.info, e.data = nil, nil, snap
    end
    return e
end

function ns.Backups()
    PlatS.profiles = PlatS.profiles or {}   -- (P4: through the Platform's settings view, the same key)
    local list = PlatS.profiles
    for i = 1, #list do Wire(list[i]) end   -- (a few backups; each already wired costs one lookup)
    return list
end

function ns.Backup_Save(name, include)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "give the backup a name first" end
    local snap = ns.Share_SnapshotAll(include, name)
    local list = ns.Backups()
    for i, p in ipairs(list) do
        if p.name == name then list[i] = KeepAsText({ name = name }, snap); return true, "updated" end
    end
    list[#list + 1] = KeepAsText({ name = name }, snap)
    return true, "saved"
end

function ns.Backup_Delete(idx) table.remove(ns.Backups(), idx) end

-- Once, at the login: every backup an older XayaUI saved as tables is kept as text from now on (only when the text reads back exactly
-- equal; otherwise it stays as it was). After the first login with this version there is nothing left to turn, and this is one pass over
-- the list of backups.
local function BackupsToText()
    local list = PlatS.profiles
    if type(list) ~= "table" then return end
    for i = 1, #list do
        local e = list[i]
        local d = type(e) == "table" and rawget(e, "data")
        if type(d) == "table" and getmetatable(d) == nil and next(d) ~= nil then KeepAsText(e, d) end
        Wire(e)
    end
end
if ns.AtLogin then ns.AtLogin(BackupsToText) end
-- (tests) the codec and the check above
ns.BackupText = { Write = BkWrite, Read = BkRead, Same = function(a, b) return Same(a, b, 0) end }

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
            for i, p in ipairs(list) do if p.name == name then list[i] = KeepAsText({ name = name }, snap); return end end
            list[#list + 1] = KeepAsText({ name = name }, snap)   -- (round 6, SD-55: kept as one text, like every backup)
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
