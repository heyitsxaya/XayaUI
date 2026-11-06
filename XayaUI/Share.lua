-------------------------------------------------------------------------------
-- Share.lua : turning XayaUI data into text you can paste to someone, and reading such text back (0.6.0; was Profile.lua).
--
-- One codec, several kinds. Every share string is  PREFIX:<checksum>:<base64 of JSON>  and the prefix says what it carries:
--   XUI1       rules: one rule, a group (with every group and rule inside it), or several rules with their groups
--   XUITHEME1  a theme (registered by Theme.lua)
-- Each kind registers a handler (ns.Share.RegisterKind): its own prefix and format version, what is never exported, how to check
-- and clean what was pasted, a one-line summary, and how to apply it. A pasted string is routed by its prefix, so a theme string
-- can never be read as rules or the other way round, and each kind can move to a new format version on its own.
-- Import NEVER runs code: the text is parsed by the data-only JSON reader below (no loadstring), then checked and cleaned by its kind.
-- Imports that change rules wait until combat ends (the combat engine's secure frames cannot be changed in combat).
-- Backups: copies of your rules saved inside XayaUI (Settings > Import / Export). The whole-setup snapshot
-- (ns.Share_SnapshotAll) is the base for the Backup feature on the roadmap (#87); there is no "export everything" button.
-------------------------------------------------------------------------------
local addonName, ns = ...

local MAX_LEN, MAX_DEPTH = 2 * 1024 * 1024, 16
local Share = { kinds = {}, byPrefix = {} }
ns.Share = Share

-------------------------------------------------------------------------------
-- JSON (data only)
-------------------------------------------------------------------------------
local function EncStr(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\"
        elseif c == "\n" then return "\\n" elseif c == "\r" then return "\\r" elseif c == "\t" then return "\\t" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function IsSeq(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
        n = n + 1
    end
    return n == #t and n > 0
end

local function Enc(v, out, depth)
    if depth > MAX_DEPTH then error("too deeply nested") end
    local t = type(v)
    if t == "string" then out[#out + 1] = EncStr(v)
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = "0"
        elseif v % 1 == 0 and math.abs(v) < 1e15 then out[#out + 1] = string.format("%d", v)
        else out[#out + 1] = string.format("%.10g", v) end
    elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
    elseif t == "table" then
        if IsSeq(v) then
            out[#out + 1] = "["
            for i = 1, #v do if i > 1 then out[#out + 1] = "," end; Enc(v[i], out, depth + 1) end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local keys = {}
            for k in pairs(v) do if type(k) == "string" then keys[#keys + 1] = k end end
            table.sort(keys)
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = "," end
                out[#out + 1] = EncStr(k) .. ":"
                Enc(v[k], out, depth + 1)
            end
            out[#out + 1] = "}"
        end
    else
        out[#out + 1] = "null"
    end
end

-- Neutralize WoW hyperlink / BNet escapes in imported text (color codes stay allowed).
local function Clean(s) return (s:gsub("|([HhKk])", "||%1")) end

local function Decode(str)
    local pos, len = 1, #str
    local function ws() pos = str:find("%S", pos) or (len + 1) end
    local val
    local function fail(m) error(m .. " at character " .. pos, 0) end
    local function parseString()
        pos = pos + 1
        local buf = {}
        while true do
            local c = str:sub(pos, pos)
            if c == "" then fail("unterminated string") end
            if c == '"' then pos = pos + 1; break end
            if c == "\\" then
                local n = str:sub(pos + 1, pos + 1)
                if n == "n" then buf[#buf + 1] = "\n" elseif n == "r" then buf[#buf + 1] = "\r"
                elseif n == "t" then buf[#buf + 1] = "\t"
                elseif n == "u" then
                    local hex = str:sub(pos + 2, pos + 5)
                    if not hex:match("^%x%x%x%x$") then fail("bad escape") end
                    local cp = tonumber(hex, 16)
                    buf[#buf + 1] = cp < 256 and string.char(cp) or "?"
                    pos = pos + 4
                elseif n == '"' or n == "\\" or n == "/" then buf[#buf + 1] = n
                else fail("bad escape") end
                pos = pos + 2
            else
                buf[#buf + 1] = c
                pos = pos + 1
            end
        end
        return Clean(table.concat(buf))
    end
    function val(depth)
        if depth > MAX_DEPTH then fail("too deeply nested") end
        ws()
        local c = str:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local t = {}
            ws()
            if str:sub(pos, pos) == "}" then pos = pos + 1; return t end
            while true do
                ws()
                if str:sub(pos, pos) ~= '"' then fail("expected key") end
                local k = parseString()
                ws()
                if str:sub(pos, pos) ~= ":" then fail("expected ':'") end
                pos = pos + 1
                t[k] = val(depth + 1)
                ws()
                local d = str:sub(pos, pos)
                pos = pos + 1
                if d == "}" then break elseif d ~= "," then fail("expected ',' or '}'") end
            end
            return t
        elseif c == "[" then
            pos = pos + 1
            local t = {}
            ws()
            if str:sub(pos, pos) == "]" then pos = pos + 1; return t end
            while true do
                t[#t + 1] = val(depth + 1)
                ws()
                local d = str:sub(pos, pos)
                pos = pos + 1
                if d == "]" then break elseif d ~= "," then fail("expected ',' or ']'") end
            end
            return t
        elseif c == '"' then return parseString()
        elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
        elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
        elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
        else
            local num = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
            if not num or num == "" then fail("unexpected character") end
            pos = pos + #num
            local n = tonumber(num)
            if not n then fail("bad number") end
            return n
        end
    end
    local r = val(0)
    ws()
    if pos <= len then fail("trailing data") end
    return r
end

-------------------------------------------------------------------------------
-- Base64 + checksum
-------------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64enc(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2, c3, c4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end
local B64R = {}
for i = 1, 64 do B64R[B64:byte(i)] = i - 1 end
local function b64dec(s)
    s = s:gsub("[^%w%+/=]", "")
    if #s % 4 ~= 0 then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local a, b, c, d = s:byte(i, i + 3)
        local va, vb = B64R[a], B64R[b]
        if not (va and vb) then return nil end
        local vc = c ~= 61 and B64R[c] or nil
        local vd = d ~= 61 and B64R[d] or nil
        if (c ~= 61 and not vc) or (d ~= 61 and not vd) then return nil end
        local n = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if vc then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if vd then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end
local function checksum(s)
    local a, b = 1, 0
    for i = 1, #s do a = (a + s:byte(i)) % 65521; b = (b + a) % 65521 end
    return string.format("%08x", b * 65536 + a)
end

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
        snap.barGroup = ns.Copy(CueRulesDB.barGroup)
    end
    if include.qol and ns.QoLOn then snap.qol = ns.Copy(ns.qolBoxes) end
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

-------------------------------------------------------------------------------
-- The codec and the kind registry
-------------------------------------------------------------------------------
-- def = {
--   kind = "rules", prefix = "XUI1", version = 1, label = "rules",
--   Strip(copy)            removes what must never leave this computer (called on a COPY before encoding)
--   Check(data) -> data | nil, err    cleans what was pasted (never trusts it); the returned value is what Apply gets
--   Describe(data) -> text            one line for the preview
--   Apply(data, mode) -> result       mode is kind-specific ("add" / "replace" for rules)
--   changesSecureFrames = true        Apply waits until combat ends
-- }
function Share.RegisterKind(def)
    assert(type(def) == "table" and type(def.kind) == "string" and type(def.prefix) == "string", "Share.RegisterKind: kind and prefix needed")
    Share.kinds[def.kind] = def
    Share.byPrefix[def.prefix] = def
end

local function Json(v)
    local out = {}
    local ok, err = pcall(Enc, v, out, 0)
    if not ok then return nil, err end
    return table.concat(out)
end
Share.Json_Encode = Json
function Share.Json_Decode(str)
    local ok, v = pcall(Decode, str)
    if not ok then return nil, v end
    return v
end

-- data -> share string. The kind's Strip runs on a copy, so nothing in your settings is touched.
function Share.Encode(kind, data)
    local def = Share.kinds[kind]
    if not def then return nil, "unknown kind " .. tostring(kind) end
    local copy = ns.Copy(data)
    copy.v = copy.v or def.version
    if def.Strip then def.Strip(copy) end
    local json, err = Json(copy)
    if not json then return nil, err end
    return def.prefix .. ":" .. checksum(json) .. ":" .. b64enc(json)
end

-- share string -> data, def   (or nil, message). Routed by the prefix; checked by the kind.
function Share.Read(str, wantKind)
    if type(str) ~= "string" then return nil, "Nothing to import." end
    str = str:gsub("%s+", "")
    if #str == 0 then return nil, "The box is empty." end
    if #str > MAX_LEN then return nil, "The text is too large." end
    local head, sum, body = str:match("^(%w+):(%x+):(.+)$")
    local def = head and Share.byPrefix[head]
    if not def then
        local known = {}
        for p, d in pairs(Share.byPrefix) do known[#known + 1] = d.label .. " (" .. p .. ":)" end
        table.sort(known)
        return nil, "This is not an XayaUI share string. XayaUI reads " .. table.concat(known, ", ") .. "."
    end
    if wantKind and def.kind ~= wantKind then
        local want = Share.kinds[wantKind]
        return nil, ("This text holds %s, not %s.%s"):format(def.label, want and want.label or wantKind, def.where and (" " .. def.where) or "")
    end
    local json = b64dec(body)
    if not json then return nil, "The text is damaged (not valid base64). Was it cut off when copying?" end
    if checksum(json) ~= sum then return nil, "The checksum does not match: the text was changed or cut off." end
    local ok, data = pcall(Decode, json)
    if not ok or type(data) ~= "table" then return nil, "Could not read the data: " .. tostring(data) end
    local v = tonumber(data.v)
    if v and v > def.version then
        local by = type(data.addonVersion) == "string" and data.addonVersion ~= "" and (" (XayaUI " .. data.addonVersion .. ")") or ""
        return nil, ("This %s was made with a newer XayaUI%s. Update XayaUI, then paste it again."):format(def.label, by)
    end
    if v ~= def.version then return nil, ("Unsupported %s format (version %s)."):format(def.label, tostring(data.v)) end
    if def.Check then
        local clean, err = def.Check(data)
        if not clean then return nil, err end
        data = clean
    end
    return data, def
end

-- run fn now, or right after combat ends when the kind changes secure frames; returns true when it ran now
local pendingCombat = {}
local combatWatch
function Share.AfterCombat(fn)
    if not (InCombatLockdown and InCombatLockdown()) then fn(); return true end
    pendingCombat[#pendingCombat + 1] = fn
    if not combatWatch and CreateFrame then
        combatWatch = CreateFrame("Frame")
        combatWatch:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local list = pendingCombat; pendingCombat = {}
            for _, f in ipairs(list) do local okc, err = pcall(f); if not okc then geterrorhandler()(err) end end
        end)
    end
    if combatWatch then combatWatch:RegisterEvent("PLAYER_REGEN_ENABLED") end
    return false
end

-- Apply already-read data of a kind. done(result) is called when it ran (at once, or after combat). Returns true when it ran now.
function Share.Apply(def, data, mode, done)
    local function run()
        local result = def.Apply(data, mode)
        if done then done(result) end
    end
    if def.changesSecureFrames then
        local now = Share.AfterCombat(run)
        if not now then ns.Print(("the %s will be imported as soon as combat ends."):format(def.label)) end
        return now
    end
    run()
    return true
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
            for _, r in ipairs(ns.rules) do ns.DropVisual(r) end
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
        local added = {}
        for _, f in ipairs(IsTbl(snap.folders) and snap.folders or {}) do
            if IsTbl(f) and type(f.id) == "string" then
                local nf = ns.Copy(f)                      -- keep the group's own settings (container type, overrides, ...)
                nf.default = nil                           -- a built-in category flag must not be duplicated here
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
            wipe(CueRulesDB.barGroup)
            for k, v in pairs(snap.barGroup) do CueRulesDB.barGroup[k] = v end
            ns.Merge(CueRulesDB.barGroup, ns.BAR_GROUP_DEFAULTS)
        end
    end

    if IsTbl(snap.qol) then
        if replace then
            for _, b in ipairs(ns.qolBoxes) do if ns.QoL_Drop then ns.QoL_Drop(b) end end
            wipe(ns.qolBoxes)
        end
        for _, b in ipairs(snap.qol) do
            if IsTbl(b) then
                ns.Merge(b, ns.QOL_BOX_DEFAULTS)
                ns.qolBoxes[#ns.qolBoxes + 1] = b
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

-------------------------------------------------------------------------------
-- Backups: copies of your rules saved inside XayaUI (CueRulesDB.profiles, the key it always had: renaming the saved key would
-- hide your backups from an older XayaUI if you went back to one). Load (add), Load (replace), show as text, delete.
-------------------------------------------------------------------------------
function ns.Backups()
    CueRulesDB.profiles = CueRulesDB.profiles or {}
    return CueRulesDB.profiles
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
