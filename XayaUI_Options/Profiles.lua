-------------------------------------------------------------------------------
-- Profiles.lua : the components of a profile, for Profiles > Import / Export (Options 0.6.66).
-- (REQUEST-LOG UI-23 to UI-27, Xaya 2026-11-06, her words: "profiles is expanded as a category bucket to include all user-created
-- customizations, settings, etc"; "individual components can be selected to toggle (review EUI and ElvUI profiling)".)
-- A profile string (share kind "profile", prefix XUIPROFILE1, the same codec as rules and themes: Share.lua) carries the components
-- ticked under Export; Import lists the components a pasted string holds, each with its own tick box.
-- Reference check (behaviour only, our implementation is independent): ElvUI's profile export offers one data type per string
-- (profile / private / global / filters) and leaves out values equal to the defaults. XayaUI keeps one account-wide CueRulesDB, so
-- its components are the window's own buckets instead, and several can travel in one string.
-- The component list, what is left out and the "settings are merged, not wiped" rule were chosen without Xaya (she was away,
-- 2026-11-07); they are in her QA question flow (key UI-27-components).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns

local P = {}
ns.Profile = P

-- key, label, saved tables (CueRulesDB keys). "rules" is special: it is the rules snapshot (rules, groups; buff bars and QoL boxes
-- while their files are loaded), applied with Add or Replace like a rules string.
P.COMPONENTS = {
    { key = "rules",  label = "Rules and groups" },
    { key = "themes", label = "Themes",          db = { "theme", "themes" } },
    { key = "settings", label = "Settings",      db = { "ui", "minimap" } },
    { key = "qol",    label = "QoL",             db = { "cursorHighlight", "cursorTrail", "characterToolkit", "releaseGuard", "cursor" } },
    { key = "bonus",  label = "Bonus Features",  db = { "dataPanels", "tooltips", "calculator" } },
    { key = "reskin", label = "Blizzard Reskin", db = { "chat2", "chat", "characterReskin", "reskinTabOff" } },
}
P.BY_KEY = {}
for _, c in ipairs(P.COMPONENTS) do P.BY_KEY[c.key] = c end

-- Never in a profile (personal data stays local; runtime state and one-time upgrade flags would break the other setup):
--   the Notepad's text, the Shopping List, the Recycle Bin, backups, drafts, logs, learned aura data (they are not in any component);
--   inside a component's tables: keys starting with "_", and the keys below.
P.NEVER = {
    ui = { defaultFolders = true, defaultFoldersV = true, folderOrdered = true, hybridMigrated = true, progressMigrated = true,
        infoPanePos = true, trayOpen = true, consoleOpen = true, console = true, rulesSub = true, cur = true, fwd = true,
        creatorIDs = true, recCats = true },
    calculator = { history = true, point = true, x = true, y = true },
    tooltips = { selfAura = true },          -- learned from your own buffs on this computer
    chat2 = { whisperSounds = "list" },      -- the per-sender whisper sounds name other players: the list is left out, the rest stays
}

local function StripUnderscore(t, depth)
    if type(t) ~= "table" or depth > 16 then return end
    for k, v in pairs(t) do
        if type(k) == "string" and k:sub(1, 1) == "_" then t[k] = nil
        elseif type(v) == "table" then StripUnderscore(v, depth + 1) end
    end
end
local function StripTable(dbKey, v)
    if type(v) ~= "table" then return v end
    StripUnderscore(v, 1)
    local never = P.NEVER[dbKey]
    if never then
        for k, how in pairs(never) do
            if how == true then v[k] = nil
            elseif type(how) == "string" and type(v[k]) == "table" then v[k][how] = nil end
        end
    end
    return v
end

-- inc = { [component key] = true }; returns the profile data (not yet encoded)
function P.Snapshot(inc, name)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local okV, ver = pcall(get, ns.name or "XayaUI", "Version")
    local data = { v = 1, name = name or "", addonVersion = (okV and ver) or "", parts = {} }
    for _, c in ipairs(P.COMPONENTS) do
        if inc[c.key] then
            if c.key == "rules" then
                data.parts.rules = ns.Share_SnapshotAll({ rules = true, bars = true, qol = true }, name)
            else
                local part = {}
                for _, k in ipairs(c.db) do
                    local v = CueRulesDB and CueRulesDB[k]
                    if v ~= nil then part[k] = StripTable(k, ns.Copy(v)) end
                end
                data.parts[c.key] = part
            end
        end
    end
    return data
end

-- the components a profile holds, in window order
function P.Held(data)
    local out = {}
    local parts = type(data) == "table" and type(data.parts) == "table" and data.parts or {}
    for _, c in ipairs(P.COMPONENTS) do if parts[c.key] ~= nil then out[#out + 1] = c end end
    return out
end

function P.Describe(data)
    local names = {}
    for _, c in ipairs(P.Held(data)) do
        if c.key == "rules" then names[#names + 1] = c.label .. " (" .. ns.Share_DescribeRules(data.parts.rules) .. ")"
        else names[#names + 1] = c.label end
    end
    if #names == 0 then return "an empty profile" end
    return "a profile with: " .. table.concat(names, "; ")
end

-- never trust what was pasted: only known components, only their own saved tables, only tables (reskinTabOff: true or nothing)
function P.Check(data)
    if type(data.parts) ~= "table" then return nil, "This profile holds nothing XayaUI can read." end
    local clean = {}
    for key, part in pairs(data.parts) do
        local c = P.BY_KEY[key]
        if c and type(part) == "table" then
            if key == "rules" then
                local rk = ns.Share.kinds.rules
                local okR, rr = pcall(rk.Check, part)
                if okR and type(rr) == "table" then clean.rules = rr end
            else
                local cp = {}
                for _, k in ipairs(c.db) do
                    local v = part[k]
                    if k == "reskinTabOff" then cp[k] = (v == true) or nil
                    elseif type(v) == "table" then cp[k] = StripTable(k, v) end
                end
                clean[key] = cp
            end
        end
    end
    data.parts = clean
    return data
end

-- inc = { [component key] = true } (nil = every component the profile holds); rulesMode = "add" | "replace"
-- Settings components are MERGED: each saved value in the profile replaces yours; values the profile does not have stay as they are.
-- Returns { done = { labels }, rules = counts or nil, reload = true when a settings component was applied }
function P.Apply(data, inc, rulesMode)
    local res = { done = {} }
    local parts = data.parts or {}
    for _, c in ipairs(P.COMPONENTS) do
        local part = parts[c.key]
        if part ~= nil and (inc == nil or inc[c.key]) then
            if c.key == "rules" then
                res.rules = ns.Share_ApplyRules(part, rulesMode == "replace" and "replace" or "add")
            else
                for _, k in ipairs(c.db) do
                    local v = part[k]
                    if k == "reskinTabOff" then
                        if v == true then CueRulesDB.reskinTabOff = true end
                    elseif type(v) == "table" then
                        local mine = CueRulesDB[k]
                        if type(mine) ~= "table" then mine = {}; CueRulesDB[k] = mine end
                        for kk, vv in pairs(v) do mine[kk] = ns.Copy(vv) end
                    end
                end
                res.reload = true
            end
            res.done[#res.done + 1] = c.label
        end
    end
    return res
end

ns.Share.RegisterKind({
    kind = "profile", prefix = "XUIPROFILE1", version = 1, label = "a profile", changesSecureFrames = true,
    where = "Profiles are imported under Profiles > Import.",
    Strip = function(data)
        local rk = ns.Share.kinds.rules
        if type(data.parts) == "table" and type(data.parts.rules) == "table" and rk and rk.Strip then rk.Strip(data.parts.rules) end
    end,
    Check = function(data) return P.Check(data) end,
    Describe = function(data) return P.Describe(data) end,
    -- mode: nil (the Import window: every component, rules added) or { inc = {...}, rules = "add" | "replace" }
    Apply = function(data, mode)
        local m = type(mode) == "table" and mode or {}
        local r = P.Apply(data, m.inc, m.rules)
        if r.reload then P.AskReload() end
        local c = r.rules or {}
        return { rules = c.rules or 0, folders = c.folders or 0, bars = c.bars or 0, qol = c.qol or 0, done = r.done, reload = r.reload }
    end,
})

-- settings are read by each feature when it starts: a reload puts the imported ones to work
function P.AskReload()
    if not StaticPopupDialogs then return end
    StaticPopupDialogs.XAYAUI_PROFILE_RELOAD = StaticPopupDialogs.XAYAUI_PROFILE_RELOAD or {
        text = "Profile imported. Reload now so every feature uses the imported settings?",
        button1 = "Reload", button2 = "Later", OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    if StaticPopup_Show then StaticPopup_Show("XAYAUI_PROFILE_RELOAD") end
end
