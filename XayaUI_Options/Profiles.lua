-------------------------------------------------------------------------------
-- Profiles.lua : the components of a profile, for Profiles > Import / Export (Options 0.6.72).
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

-- (Options 0.6.80; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.1, PS-6) The parts of a profile are no longer a fixed list here:
-- each module registers its own with ns.RegisterProfilePart (core Modules.lua), and this file only walks what is registered. A module
-- that is switched off registers nothing: its part is not offered under Export, and Import keeps it in the pasted profile, shows
-- "needs <addon title>" and skips it. Who registers what today (the keys are unchanged, so a profile string is byte-for-byte what it
-- was before for the same setup; tests/profile_parts_run.py):
--   Rules and groups  core Share.lua (the rule-tracking side)     Themes          core Theme.lua (theme, themes; also theme scopes)
--   Settings          core Modules.lua (ui, minimap)              QoL             XayaUI_QoL/ProfilePart.lua
--   Bonus Features    XayaUI_Bonus/ProfilePart.lua                Blizzard Reskin core Modules.lua (chat2, chat, characterReskin,
--   Nameplates        XayaUI_Nameplates/Core.lua (new)                            reskinTabOff: three modules' keys, kept as one part)
-- Never in a profile (personal data stays local): the Notepad's text, the Shopping List, the Recycle Bin, backups, drafts, logs,
-- learned aura data (no part holds them); inside a part, keys starting with "_" and what the part's `never` names.
P.COMPONENTS = ns.ProfileParts and ns.ProfileParts() or {}     -- the registered parts, in window order (a live list)
P.BY_KEY = ns.ProfilePartsByKey and ns.ProfilePartsByKey() or {}
-- (kept for readers of the old name) every part's `never`, by part key
P.NEVER = setmetatable({}, { __index = function(_, k) local c = P.BY_KEY[k]; return c and c.never end })

-- Parts a profile string could hold before parts carried their own information (format 1, before Options 0.6.80): which addon each
-- belongs to, so Import can say which addon a part needs when that addon is not loaded. Newer parts carry it in the string
-- (data.partInfo[key] = { v = version, module = folder, title = addon title, label = label }); these six carry none, so their
-- strings stay exactly as before.
P.LEGACY = {
    rules = { module = "XayaUI", title = "XayaUI", label = "Rules and groups" },
    themes = { module = "XayaUI", title = "XayaUI", label = "Themes" },
    settings = { module = "XayaUI", title = "XayaUI", label = "Settings" },
    qol = { module = "XayaUI_QoL", title = "XayaUI QoL", label = "QoL" },
    bonus = { module = "XayaUI_Bonus", title = "XayaUI Bonus Features", label = "Bonus Features" },
    reskin = { module = "XayaUI", title = "XayaUI", label = "Blizzard Reskin" },
}
local function Report(err) local h = geterrorhandler and geterrorhandler(); if h then h(err) end end
local function PartInfo(data, key)
    local i = type(data) == "table" and type(data.partInfo) == "table" and data.partInfo[key]
    if type(i) == "table" then return i end
    return P.LEGACY[key]
end
-- the format version a pasted part was written in (1 when the string says nothing)
function P.PartVersion(data, key) local i = PartInfo(data, key); return (type(i) == "table" and tonumber(i.v)) or 1 end

-- inc = { [part key] = true }; returns the profile data (not yet encoded)
function P.Snapshot(inc, name)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local okV, ver = pcall(get, ns.name or "XayaUI", "Version")
    local data = { v = 1, name = name or "", addonVersion = (okV and ver) or "", parts = {} }
    for _, c in ipairs(P.COMPONENTS) do
        if inc[c.key] then
            local ok, part = pcall(c.snapshot, name)
            if ok and type(part) == "table" then
                data.parts[c.key] = part
                -- a part that is not one of the six format-1 parts, or a newer version of one, says what it is and which addon reads it
                if not P.LEGACY[c.key] or c.version ~= 1 then
                    data.partInfo = data.partInfo or {}
                    data.partInfo[c.key] = { v = c.version, module = c.module, title = ns.AddonTitle and ns.AddonTitle(c.module) or c.module, label = c.label }
                end
            elseif not ok then Report(part) end
        end
    end
    return data
end

-- the registered parts a profile holds, in window order
function P.Held(data)
    local out = {}
    local parts = type(data) == "table" and type(data.parts) == "table" and data.parts or {}
    for _, c in ipairs(P.COMPONENTS) do if parts[c.key] ~= nil then out[#out + 1] = c end end
    return out
end

-- the parts a profile holds that no loaded module registered: { key, label, title } in key order (Import: "needs <title>")
function P.Missing(data)
    local out = {}
    local parts = type(data) == "table" and type(data.parts) == "table" and data.parts or {}
    for key in pairs(parts) do
        if not P.BY_KEY[key] then
            local i = PartInfo(data, key) or {}
            out[#out + 1] = { key = key, label = tostring(i.label or key), title = tostring(i.title or i.module or key) }
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end

function P.Describe(data)
    local names = {}
    for _, c in ipairs(P.Held(data)) do
        if c.describe then
            local ok, d = pcall(c.describe, data.parts[c.key])
            names[#names + 1] = (ok and type(d) == "string") and (c.label .. " (" .. d .. ")") or c.label
        else names[#names + 1] = c.label end
    end
    if #names == 0 then return "an empty profile" end
    return "a profile with: " .. table.concat(names, "; ")
end

-- never trust what was pasted: each registered part cleans its own data; a part of a module that is not loaded is kept as it came
-- (only when it names its addon, or is one of the format-1 parts) and is never applied; anything else is dropped
function P.Check(data)
    if type(data.parts) ~= "table" then return nil, "This profile holds nothing XayaUI can read." end
    local clean, info = {}, {}
    for key, part in pairs(data.parts) do
        local c = P.BY_KEY[key]
        if type(key) == "string" and type(part) == "table" then
            if c then
                local ok, cp = pcall(c.check, part)
                if ok and type(cp) == "table" then clean[key] = cp elseif not ok then Report(cp) end
            else
                local i = type(data.partInfo) == "table" and data.partInfo[key]
                if type(i) == "table" and type(i.module) == "string" then clean[key] = part
                elseif P.LEGACY[key] then clean[key] = part end
            end
        end
    end
    if type(data.partInfo) == "table" then
        for key, i in pairs(data.partInfo) do
            if clean[key] ~= nil and type(i) == "table" then
                local s = function(v) return (type(v) == "string" and #v <= 80) and v or nil end
                info[key] = { v = tonumber(i.v), module = s(i.module), title = s(i.title), label = s(i.label) }
            end
        end
    end
    data.parts = clean
    data.partInfo = next(info) and info or nil
    return data
end

-- inc = { [part key] = true } (nil = every part the profile holds); rulesMode = "add" | "replace" (the mode of the "rules" part);
-- modes = { [part key] = mode } for any other part (nil: the part's default; every settings part today merges).
-- Settings parts are MERGED: each saved value in the profile replaces yours; values the profile does not have stay as they are.
-- Returns { done = { labels }, rules = counts or nil, reload = true when a part that needs a reload was applied,
--   skipped = { addon titles } for held parts whose module is not loaded }
function P.Apply(data, inc, rulesMode, modes)
    local res = { done = {}, skipped = {} }
    local parts = data.parts or {}
    for _, c in ipairs(P.COMPONENTS) do
        local part = parts[c.key]
        if part ~= nil and (inc == nil or inc[c.key]) then
            local mode = (type(modes) == "table" and modes[c.key]) or (c.key == "rules" and rulesMode) or nil
            local ok, r = pcall(c.apply, part, mode, P.PartVersion(data, c.key))
            if ok then
                if c.key == "rules" then res.rules = r end
                if c.reload ~= false then res.reload = true end
                res.done[#res.done + 1] = c.label
            else
                Report(r)
            end
        end
    end
    for _, m in ipairs(P.Missing(data)) do
        if inc == nil or inc[m.key] then res.skipped[#res.skipped + 1] = m.title end
    end
    return res
end

ns.Share.RegisterKind({
    kind = "profile", prefix = "XUIPROFILE1", version = 1, label = "a profile", changesSecureFrames = true,
    where = "Profiles are imported under Profiles > Import.",
    Strip = function(data)
        if type(data.parts) ~= "table" then return end
        for _, c in ipairs(P.COMPONENTS) do
            if c.strip and type(data.parts[c.key]) == "table" then local ok, err = pcall(c.strip, data.parts[c.key]); if not ok then Report(err) end end
        end
    end,
    Check = function(data) return P.Check(data) end,
    Describe = function(data) return P.Describe(data) end,
    -- mode: nil (the Import window: every component, rules added) or { inc = {...}, rules = "add" | "replace" }
    Apply = function(data, mode)
        local m = type(mode) == "table" and mode or {}
        local r = P.Apply(data, m.inc, m.rules, m.modes)
        if r.reload then P.AskReload() end
        local c = r.rules or {}
        return { rules = c.rules or 0, folders = c.folders or 0, bars = c.bars or 0, qol = c.qol or 0, done = r.done, reload = r.reload, skipped = r.skipped }
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
