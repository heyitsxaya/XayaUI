-------------------------------------------------------------------------------
-- Profile.lua : export / import of the whole configured system, plus named
-- profiles saved inside the addon.
--
-- A snapshot holds: rules (with folders), buff bars (+ group layout), QoL boxes.
-- Export string:  XUI1:<checksum>:<base64 of JSON>.   Import NEVER runs code:
-- the string is parsed by the data-only reader below, then normalised.
-------------------------------------------------------------------------------
local addonName, ns = ...

local FORMAT = "XUI1"
local MAX_LEN, MAX_DEPTH = 2 * 1024 * 1024, 16

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

-- Neutralise WoW hyperlink / BNet escapes in imported text (colour codes stay allowed).
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
function ns.Profile_Snapshot(include, name)
    include = include or { rules = true, bars = true, qol = true }
    local snap = { v = 1, name = name or "", addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "" }
    if include.rules then
        snap.rules = ns.Copy(ns.rules)
        snap.folders = ns.Copy(ns.folders)
    end
    if include.bars then
        snap.bars = ns.Copy(ns.bars)
        snap.barGroup = ns.Copy(CueRulesDB.barGroup)
    end
    if include.qol then snap.qol = ns.Copy(ns.qolBoxes) end
    return snap
end

function ns.Profile_Encode(snap)
    local out = {}
    local ok, err = pcall(Enc, snap, out, 0)
    if not ok then return nil, err end
    local json = table.concat(out)
    return FORMAT .. ":" .. checksum(json) .. ":" .. b64enc(json)
end

function ns.Profile_Decode(str)
    if type(str) ~= "string" then return nil, "nothing to import" end
    str = str:gsub("%s+", "")
    if #str == 0 then return nil, "the box is empty" end
    if #str > MAX_LEN then return nil, "the text is too large" end
    local head, sum, body = str:match("^(%w+):(%x+):(.+)$")
    if head ~= FORMAT then return nil, "this is not an XayaUI profile string (it should start with " .. FORMAT .. ":)" end
    local json = b64dec(body)
    if not json then return nil, "the text is damaged (not valid base64) - was it cut off when copying?" end
    if checksum(json) ~= sum then return nil, "the checksum does not match - the text was changed or cut off" end
    local ok, snap = pcall(Decode, json)
    if not ok then return nil, "could not read the data: " .. tostring(snap) end
    if type(snap) ~= "table" or snap.v ~= 1 then return nil, "unsupported profile version" end
    return snap
end

-- Plain-language description of a snapshot (for the import preview).
function ns.Profile_Describe(snap)
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
function ns.Profile_Apply(snap, mode)
    local counts = { rules = 0, folders = 0, bars = 0, qol = 0 }
    local replace = (mode == "replace")

    if IsTbl(snap.rules) then
        if replace then
            for _, r in ipairs(ns.rules) do ns.DropVisual(r) end
            wipe(ns.rules); wipe(ns.folders)
        end
        local used, map = {}, {}
        for _, f in ipairs(ns.folders) do used[f.id] = true end
        local added = {}
        for _, f in ipairs(IsTbl(snap.folders) and snap.folders or {}) do
            if IsTbl(f) and type(f.id) == "string" then
                local nf = { id = f.id, name = type(f.name) == "string" and f.name or "Folder" }
                if used[nf.id] then nf.id = NewId(used) else used[nf.id] = true end
                map[f.id] = nf.id
                ns.folders[#ns.folders + 1] = nf
                added[#added + 1] = { nf = nf, oldParent = type(f.parent) == "string" and f.parent or nil }
                counts.folders = counts.folders + 1
            end
        end
        for _, a in ipairs(added) do a.nf.parent = a.oldParent and map[a.oldParent] or nil end
        for _, r in ipairs(snap.rules) do
            if IsTbl(r) then
                ns.NormalizeRule(r)
                if r.folder ~= nil then r.folder = map[r.folder] end
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
            for _, b in ipairs(ns.qolBoxes) do ns.QoL_Drop(b) end
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
    if ns.OnRulesChanged then ns.OnRulesChanged() end
    return counts
end

-------------------------------------------------------------------------------
-- Named profiles stored in the addon (SavedVariables)
-------------------------------------------------------------------------------
function ns.Profiles()
    CueRulesDB.profiles = CueRulesDB.profiles or {}
    return CueRulesDB.profiles
end

function ns.Profile_Save(name, include)
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "give the profile a name first" end
    local snap = ns.Profile_Snapshot(include, name)
    local list = ns.Profiles()
    for i, p in ipairs(list) do
        if p.name == name then list[i] = { name = name, data = snap }; return true, "updated" end
    end
    list[#list + 1] = { name = name, data = snap }
    return true, "saved"
end

function ns.Profile_Delete(idx) table.remove(ns.Profiles(), idx) end
