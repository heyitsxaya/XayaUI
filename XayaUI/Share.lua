-------------------------------------------------------------------------------
-- Share.lua : turning XayaUI data into text you can paste to someone, and reading such text back (0.6.0; was Profile.lua).
--
-- One codec, several kinds. Every share string is  PREFIX:<checksum>:<base64 of JSON>  and the prefix says what it carries:
--   XUI1       rules: one rule, a group (with every group and rule inside it), or several rules with their groups (registered by
--              XayaUI Rules: XayaUI_Rules/RuleShare.lua, P4)
--   XUITHEME1  a theme (registered by Theme.lua)
-- Each kind registers a handler (ns.Share.RegisterKind): its own prefix and format version, what is never exported, how to check
-- and clean what was pasted, a one-line summary, and how to apply it. A pasted string is routed by its prefix, so a theme string
-- can never be read as rules or the other way round, and each kind can move to a new format version on its own.
-- Import NEVER runs code: the text is parsed by the data-only JSON reader below (no loadstring), then checked and cleaned by its kind.
-- Imports of a kind that changes secure frames (rules) wait until combat ends (Share.AfterCombat below).
-- The rules snapshots, the rules kind, the "Rules and groups" profile part and the rule backups are XayaUI Rules' since the platform
-- split (P4): XayaUI_Rules/RuleShare.lua.
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

-- The same codec (PREFIX:<checksum>:<base64 of JSON>) for text that is not imported into XayaUI, so no kind is registered for it and
-- the Import window refuses it (core 0.6.56: the debug report string, DebugRecord.lua; XayaUI Dev Assist reads it back).
function Share.Pack(prefix, data)
    local json, err = Json(data)
    if not json then return nil, err end
    return prefix .. ":" .. checksum(json) .. ":" .. b64enc(json)
end
function Share.Unpack(str, prefix)
    if type(str) ~= "string" then return nil, "Nothing to read." end
    str = str:gsub("%s+", "")
    if #str == 0 then return nil, "The box is empty." end
    if #str > MAX_LEN then return nil, "The text is too large." end
    local head, sum, body = str:match("^(%w+):(%x+):(.+)$")
    if head ~= prefix then return nil, "This is not a " .. prefix .. " string." end
    local json = b64dec(body)
    if not json then return nil, "The text is damaged (not valid base64). Was it cut off when copying?" end
    if checksum(json) ~= sum then return nil, "The checksum does not match: the text was changed or cut off." end
    local ok, data = pcall(Decode, json)
    if not ok or type(data) ~= "table" then return nil, "Could not read the data: " .. tostring(data) end
    return data
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
    if not def and head then   -- (P4) the kind of a module that is switched off (Modules.lua ns.MODULES sharePrefixes): "needs <addon title>"
        for _, m in ipairs(ns.MODULES or {}) do
            for _, p in ipairs(m.sharePrefixes or {}) do if p == head then return nil, "needs " .. m.title end end
        end
    end
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
