-------------------------------------------------------------------------------
-- Modules.lua : the contract between XayaUI core and the features that plug into it (0.5.108).
--
-- XayaUI is being split into separate addons that can each be switched on or off in the game's AddOns list:
--   XayaUI          core: rules, the combat aura engine, profiles, theme, console, minimap button, ESC-menu button
--   XayaUI_Chat     every chat change and feature
--   XayaUI_QoL      cursor changes (friends and bags later)
--   XayaUI_Bonus    enhanced tooltips, notepad, custom data panels
--   XayaUI_Reskin   Blizzard frames restyled without changing what they do
--   XayaUI_Options  the settings window, loaded the first time it opens
-- Core never calls a feature by name. A feature registers what it offers here, and core only walks these lists, so a feature
-- that is switched off (or not installed) simply leaves nothing behind:
--   ns.WhenReady(fn)                          run fn once the saved settings exist (right away if they already do)
--   ns.RegisterCommand(names, fn, help)       /xui <name> [args]; names is one string or a list; several handlers may share a name
--   ns.RegisterLauncher(entry)                a row in the minimap button's quick-access list
--   ns.RegisterSettingsPage(module, key, fn)  a page in the settings window; fn(Notify) returns an AceConfig group
--   ns.RegisterReskin(key, apply)             a reskin of the Blizzard UI Reskin tab; apply() takes the tab's switch (core 0.6.51)
--   ns.MODULES                                which addon owns which /xui commands, so core can say why one does nothing
-- Every registered function is called through pcall: one feature's error never stops the next one from starting.
-- Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local _, ns = ...

local function Report(err)
    local h = geterrorhandler and geterrorhandler()
    if h then h(err) end
end
local function Call(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Report(err) end
    return ok
end

-------------------------------------------------------------------------------
-- 0b. Settings seam (core 0.6.75; P2, docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5 step 1, PS-7, Xaya 2026-11-07: "I imagine
-- we want individual modules to hold their own settings, correct?"). First in this file, so every file loaded after Modules.lua (and
-- every feature addon) has it. ns.Settings(module) returns that module's settings view:
--   local S = ns.Settings("qol"); local c = S.cursorTrail; S.cursorTrail = c or {}
-- module = "platform", "core" (rule tracking), "qol", "chat", "bonus", "reskin" or "devassist" (XayaUI Nameplates keeps its own
-- XayaUINameplatesDB). (P5) A module listed in OWN_STORE below keeps its settings in its own saved variable (XayaUIReskinDB ...),
-- copied there from CueRulesDB once (section 0c); the others still read and write their CueRulesDB keys. The call sites never change.
--   * A view holds no data: each access looks up the current backing table, so a view kept in an upvalue still sees new data after
--     anything replaces CueRulesDB, a module's store or one of their keys (the loader setting the saved variables, a profile import,
--     Reset all, a restore). (P5) Until a module's store is open (its addon's ADDON_LOADED) its view reads nil and a write is dropped
--     (counted in ns.SettingsDroppedWrites): a module that is switched off has nothing made for it (V14). Code that reads its settings
--     at start-up waits with ns.WhenSettingsReady(module, fn).
--   * Reads never create anything; a write creates only the key written (and CueRulesDB itself when it does not exist yet, as the
--     sites that wrote it did). ns.SettingsReady() says whether the backing exists (the old "type(CueRulesDB) == 'table'" guard).
--   * The views are made once, here, when this file loads: calling ns.Settings, for any module, on or off, creates nothing (V14).
--   * Each module reads its OWN keys through its own view; another module's keys go through that owner's view
--     (ns.Settings("chat").chat, never a QoL view). A key no list below names still reads and writes through (nothing breaks in
--     game); it is counted in ns.SettingsUnknownKeys() and, with ns.SettingsStrict(true) (tests), raises an error.
--   * Hot paths (per frame, per aura event, per tooltip) keep the table in an upvalue and re-read it only when ns.settingsEpoch
--     changes: no metamethod per frame. The epoch moves on every view write of a key, on ns.SettingsChanged() (the Platform calls it
--     after the saved settings are set up and after a profile part is applied) and when CueRulesDB itself is a different table.
-------------------------------------------------------------------------------

-- Key owners, confirmed against the code (the plan's section 5 table was an inference; the differences are in the P2 debug-log entry;
-- the P5 changes, from Xaya's answers PS-52 / PS-53 / PS-54, in the P5 debug-log entry, debug-log/*-settings-migration-p5-*.md).
local SETTINGS_KEYS = {
    platform  = { "theme", "themes", "ui", "minimap", "profiles", "recycleBin", "errorLog", "errors", "lastBugReport", "debugRecord",
                  "version", "reskinTabOff" },
    core      = { "rules", "folders", "bars", "barGroup", "drafts", "moverDraft", "auraAlias", "auraModel", "auraSources", "auraTracker",
                  "classLearn", "learnedAuraDur", "learnedAuraStacks", "learnedCooldown", "procGlowSeen", "engineDisplay", "cuesVer",
                  "backupPreCues", "setupBuildError", "setupShowError",
                  -- (P5) the rules' own switches, kept in CueRulesDB.ui before (LEGACY_UNDER_UI); only XayaUI Rules / Rules Options read them
                  "snapMode", "auto", "creatorIDs", "folderOrdered", "defaultFolders", "defaultFoldersV", "hybridMigrated", "progressMigrated",
                  "skipSoundAllPrompt", "promptSave", "draftsMax", "draftsConfirmDiscard", "draftsConfirmDelete", "draftsCloseNotice" },
    qol       = { "qol", "cursor", "cursorHighlight", "cursorTrail", "characterToolkit", "characterReskin", "shoppingList", "releaseGuard" },
    chat      = { "chat", "chat2" },
    bonus     = { "dataPanels", "tooltips", "calculator", "notepad" },
    -- rsk / gm / friendColors were kept inside CueRulesDB.ui (LEGACY_UNDER_UI). characterReskin is split (P5, Xaya PS-53: "Character ui
    -- *reskin* is a blizzard change. Functionality changes or enhancements are separate."): Reskin keeps the sub-keys that only change
    -- the LOOK of Blizzard's character window (LEGACY_SPLIT), QoL the rest; the code (XayaUI_QoL/CharacterReskin.lua) reads both.
    reskin    = { "rsk", "gm", "friendColors", "characterReskin" },
    -- (P5) perfLog: Dev Assist's (B11; XayaUI Rules' Engine.lua writes it through this view, only while Dev Assist is on); the detailed
    -- record's own settings, kept in CueRulesDB.ui before (LEGACY_UNDER_UI)
    devassist = { "idProbe", "idProbeStream", "chatProbe", "perfLog", "recCats", "recFocus", "recordOff", "recordMax", "debugProbe", "probeByDebug" },
}
-- (P5) where a module's key lived in CueRulesDB before the module had its own saved variable: inside CueRulesDB.ui ...
local LEGACY_UNDER_UI = {
    core      = { snapMode = true, auto = true, creatorIDs = true, folderOrdered = true, defaultFolders = true, defaultFoldersV = true,
                  hybridMigrated = true, progressMigrated = true, skipSoundAllPrompt = true, promptSave = true, draftsMax = true,
                  draftsConfirmDiscard = true, draftsConfirmDelete = true, draftsCloseNotice = true },
    reskin    = { rsk = true, gm = true, friendColors = true },
    devassist = { recCats = true, recFocus = true, recordOff = true, recordMax = true, debugProbe = true, probeByDebug = true },
}
-- ... or as some sub-keys of a CueRulesDB key two modules share: { [key] = { owner = the module that keeps `sub`, sub = {...}, rest = the
-- module that keeps every other sub-key } }. The look of the character window (Reskin): the switch, the window chrome, the stat list's
-- art, the background's opacity, the wider window and the extra height (and the one-time widePx step). The rest (QoL): item level,
-- enchant and gem blocks, the full stat list and how it is organised (Xaya PS-54: the character pane's stat organisation is QoL's).
local LEGACY_SPLIT = {
    characterReskin = { owner = "reskin", rest = "qol", sub = { enabled = true, chrome = true, stats = true, bgAlpha = true, wide = true,
        widePx = true, widePxTo42 = true, tallPx = true } },
}
-- (P5, plan section 5 steps 2-3) the modules that keep their settings in a saved variable of their own. A module not listed here keeps
-- its keys in CueRulesDB (the Platform's). Which variable, and which addon loads it, the module itself says from its own first file
-- (ns.SettingsDeclareStore, below; its .toc declares the variable): the Platform never names a module's addon or saved file (a module
-- that is switched off declares nothing, and its view then reads nil and keeps nothing: V14).
local OWN_STORE = { reskin = true, chat = true, bonus = true, qol = true, devassist = true, core = true }
local SETTINGS_STORES = {}   -- module -> { addon, var }, as declared
function ns.SettingsDeclareStore(module, addon, var)
    if OWN_STORE[module] and type(addon) == "string" and type(var) == "string" and not SETTINGS_STORES[module] then
        SETTINGS_STORES[module] = { addon = addon, var = var }
        -- (tests only, ns.settingsTestHooks.keepOld: single-file tests that keep a module's data in CueRulesDB as before P5)
        if ns.settingsTestHooks and ns.settingsTestHooks.keepOld and ns.SettingsOpen then ns.SettingsOpen(module) end
    end
end

ns.settingsEpoch = 0
local settingsUnknown, settingsDropped, settingsStrict, lastBacking = {}, {}, false, nil
local function Backing()
    local db = rawget(_G, "CueRulesDB")
    if db ~= lastBacking then lastBacking = db; ns.settingsEpoch = ns.settingsEpoch + 1 end
    if type(db) == "table" then return db end
    return nil
end
-- (P5) storeState[module]: nil = its store is not open (the module's addon has not loaded yet, or is switched off: reads give nil, writes
-- are dropped and counted, nothing is made); "own" = its own saved variable; "old" = the copy failed its check, so the module keeps
-- CueRulesDB (laid out as before)
local storeState, lastStore, copiedNow = {}, {}, {}   -- copiedNow[module]: the copy was made in this session
local function StoreOf(module)
    local st = SETTINGS_STORES[module]
    local t = rawget(_G, st.var)
    if t ~= lastStore[module] then lastStore[module] = t; ns.settingsEpoch = ns.settingsEpoch + 1 end
    return type(t) == "table" and t or nil
end
-- the table a module's view reads, and whether it is laid out as CueRulesDB was (legacy = true)
local function ModuleBacking(module)
    if not OWN_STORE[module] or storeState[module] == "old" then return Backing(), true end
    if storeState[module] == "own" then return StoreOf(module), false end
    return nil, false
end
function ns.SettingsChanged() ns.settingsEpoch = ns.settingsEpoch + 1 end
-- module (optional): that module's settings can be read and written now; without it: the Platform's CueRulesDB exists
function ns.SettingsReady(module)
    if module == nil or module == "platform" or not OWN_STORE[module] then return Backing() ~= nil end
    return storeState[module] ~= nil and (ModuleBacking(module)) ~= nil
end
function ns.SettingsStrict(on) settingsStrict = on and true or false end
function ns.SettingsUnknownKeys() return settingsUnknown end
-- (P5, tests) writes that found their module's store not open (switched off, or not loaded yet), by "module.key"
function ns.SettingsDroppedWrites() return settingsDropped end

local settingsViews, settingsOwned = {}, {}
local function MakeView(module)
    local owned, underUi = {}, LEGACY_UNDER_UI[module] or {}
    for _, k in ipairs(SETTINGS_KEYS[module]) do owned[k] = true end
    settingsOwned[module] = owned
    local function Check(k)
        if owned[k] then return end
        local id = module .. "." .. tostring(k)
        settingsUnknown[id] = (settingsUnknown[id] or 0) + 1
        if settingsStrict then error("XayaUI settings: " .. module .. " does not own the key " .. tostring(k), 3) end
    end
    return setmetatable({}, {
        __index = function(_, k)
            Check(k)
            local db, legacy = ModuleBacking(module)
            if not db then return nil end
            if legacy and underUi[k] then   -- (not `type(ui) == "table" and ui[k] or nil`: a saved false would read as nil)
                local ui = db.ui
                if type(ui) ~= "table" then return nil end
                return ui[k]
            end
            return db[k]
        end,
        __newindex = function(_, k, v)
            Check(k)
            local db, legacy = ModuleBacking(module)
            if not db then
                if OWN_STORE[module] and storeState[module] == nil then   -- not open: off or not loaded yet (V14: nothing is made)
                    local id = module .. "." .. tostring(k)
                    settingsDropped[id] = (settingsDropped[id] or 0) + 1
                    if settingsStrict then error("XayaUI settings: " .. module .. "'s settings are not open (key " .. tostring(k) .. ")", 2) end
                    return
                elseif OWN_STORE[module] and storeState[module] == "own" then
                    db = {}; _G[SETTINGS_STORES[module].var] = db; StoreOf(module)
                else
                    db = {}; _G.CueRulesDB = db; Backing()
                end
            end
            local t = db
            if legacy and underUi[k] then
                if type(db.ui) ~= "table" then db.ui = {} end
                t = db.ui
            end
            if t[k] ~= v then   -- "S.x = S.x or {}" writes the same table back: no epoch move for that
                t[k] = v
                ns.settingsEpoch = ns.settingsEpoch + 1
            end
        end,
        __metatable = false,
    })
end
for module in pairs(SETTINGS_KEYS) do settingsViews[module] = MakeView(module) end

-- the module's settings view, or nil for a name that is not a module
function ns.Settings(module) return settingsViews[module] end
-- (tests) the keys a module owns, in list order, and the key a view key was stored under in CueRulesDB ("ui.rsk" for Reskin's rsk)
function ns.SettingsKeys(module)
    local out = {}
    for _, k in ipairs(SETTINGS_KEYS[module] or {}) do out[#out + 1] = k end
    return out
end
function ns.SettingsStoredAt(module, k)
    if not (settingsOwned[module] and settingsOwned[module][k]) then return nil end
    return ((LEGACY_UNDER_UI[module] or {})[k] and "ui." or "") .. k
end
-- (P5) where a module's settings are kept now: { var = "XayaUIQoLDB" | "CueRulesDB", state = "own" | "old" | "closed" | "platform",
-- addon, ownVar }; nil for a name that is not a module
function ns.SettingsStore(module)
    if not OWN_STORE[module] then return settingsViews[module] and { var = "CueRulesDB", state = "platform" } or nil end
    local st = SETTINGS_STORES[module] or {}   -- (not declared: the module's addon is off or not loaded yet)
    local out = { var = storeState[module] == "old" and "CueRulesDB" or st.var, state = storeState[module] or "closed", addon = st.addon,
        ownVar = st.var, copiedNow = copiedNow[module] == true }
    -- what the copy recorded in the store (for the QA walkthrough and /dump; copies, read only)
    local t = st.var and rawget(_G, st.var)
    if type(t) == "table" then
        out.migratedFrom, out.migratedAt, out.migratedBy, out.migratedKeys = t.migratedFrom, t.migratedAt, t.migratedBy, t.migratedKeys
        local mm = t.migrationMismatch
        if type(mm) == "table" then out.mismatch = { at = mm.at, by = mm.by, diff = mm.diff, tries = mm.tries } end
    end
    return out
end
-- (P5) the modules that have their own store, sorted
function ns.SettingsStoreModules()
    local out = {}
    for m in pairs(OWN_STORE) do out[#out + 1] = m end
    table.sort(out)
    return out
end

-------------------------------------------------------------------------------
-- 0c. Settings migration (P5; plan section 5 steps 2-3, risk R1): copy, never move. When a module's addon loads (its ADDON_LOADED, after
-- the game has set its saved variable) its store is opened. The first time (the store has neither a setting nor storeVersion), every key
-- of the module that exists in CueRulesDB is deep-copied across and the copy is compared with the original; on any difference the copy
-- is taken out again, the module keeps reading CueRulesDB, the difference is recorded (migrationMismatch) and the player is told once.
-- Otherwise the store records migratedFrom / migratedAt / migratedBy / migratedKeys. CueRulesDB is never changed by this: going back to
-- an older XayaUI finds every setting as it was at the copy (what is changed after the copy lives only in the new store). A second
-- load never copies again. XayaUI Rules adds a backup of the rules before its copy and compares the counts of rules, groups and bars
-- (ns.SettingsMigrationGuard, XayaUI_Rules/RuleShare.lua).
-------------------------------------------------------------------------------
local function DeepCopy(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return v end
    if depth > 60 then error("nested deeper than 60") end
    local out = {}
    for k, x in pairs(v) do out[DeepCopy(k, depth + 1)] = DeepCopy(x, depth + 1) end
    return out
end
-- equal by value (tables by contents, both ways; NaN equals NaN): nil, or the path of the first difference
local function Differs(a, b, path, depth)
    path, depth = path or "", depth or 0
    if type(a) ~= type(b) then return path .. " (" .. type(a) .. " vs " .. type(b) .. ")" end
    if type(a) ~= "table" then
        if a == b or (a ~= a and b ~= b) then return nil end
        return path
    end
    if depth > 60 then return path .. " (too deep)" end
    for k, x in pairs(a) do
        if type(k) == "table" then return path .. " (table key)" end
        local d = Differs(x, b[k], path .. "." .. tostring(k), depth + 1)
        if d then return d end
    end
    for k in pairs(b) do if a[k] == nil then return path .. "." .. tostring(k) .. " (extra)" end end
    return nil
end
ns.SettingsDiffers = Differs   -- (the Rules guard and the tests)
-- what a module's key held in CueRulesDB before its store (a split key: only this module's sub-keys); nil when there is nothing
local function LegacyValue(module, k, old)
    if type(old) ~= "table" then return nil end
    local v
    if (LEGACY_UNDER_UI[module] or {})[k] then
        if type(old.ui) == "table" then v = old.ui[k] end   -- (a saved false stays false)
    else v = old[k] end
    local split = LEGACY_SPLIT[k]
    if split and type(v) == "table" then
        local part = {}
        for kk, x in pairs(v) do
            if (split.owner == module and split.sub[kk]) or (split.rest == module and not split.sub[kk]) then part[kk] = x end
        end
        if next(part) == nil then return nil end
        return part
    end
    return v
end
ns.SettingsLegacyValue = LegacyValue   -- (tests: what the copy takes from a CueRulesDB)
-- (the QA walkthrough) a copy of what a module's key still holds in CueRulesDB (the old place, kept untouched until P6), read only
function ns.SettingsOldValue(module, k) return DeepCopy(LegacyValue(module, k, Backing())) end
-- the sub-keys of a split key that its owner keeps ({ [sub key] = true }, a copy), or nil (XayaUI_QoL/CharacterReskin.lua reads the look keys)
function ns.SettingsSplitSub(key)
    local split = LEGACY_SPLIT[key]
    if not split then return nil end
    local out = {}
    for k in pairs(split.sub) do out[k] = true end
    return out, split.owner, split.rest
end

local readyFor = {}          -- module -> functions waiting for its store (ns.WhenSettingsReady)
local migrationGuards = {}   -- module -> { before = fn(old), check = fn(old, store) -> nil | difference text }
function ns.SettingsMigrationGuard(module, def) if OWN_STORE[module] and type(def) == "table" then migrationGuards[module] = def end end
ns.settingsTestHooks = ns.settingsTestHooks or {}   -- (tests only) afterCopy(module, store): see or change the copy (the mismatch path);
-- keepOld = true: every store stays closed to the copy and its module reads CueRulesDB as before P5 (the reference to compare with)

local function Meta(addon, field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, addon, field)
    return (ok and type(v) == "string" and v ~= "") and v or nil
end
local function HasSettings(store, module)
    if store.storeVersion ~= nil then return true end
    for _, k in ipairs(SETTINGS_KEYS[module]) do if store[k] ~= nil then return true end end
    return false
end
local function Stamp() return date and date("%Y-%m-%d %H:%M") or "?" end

local function OpenStore(module)
    local st = SETTINGS_STORES[module]
    if ns.settingsTestHooks.keepOld then return "old" end   -- (tests only: read CueRulesDB exactly as before P5, to compare against)
    local old = Backing()
    local store = rawget(_G, st.var)
    if type(store) ~= "table" then store = nil end
    if store and HasSettings(store, module) then return "own" end   -- opened before: never copy again
    local copied, n = {}, 0
    for _, k in ipairs(SETTINGS_KEYS[module]) do
        local v = LegacyValue(module, k, old)
        if v ~= nil then copied[k] = v; n = n + 1 end
    end
    store = store or {}
    _G[st.var] = store
    if n > 0 then
        local guard = migrationGuards[module]
        if guard and guard.before then Call(guard.before, old) end   -- (XayaUI Rules: a backup of the rules first)
        for k, v in pairs(copied) do store[k] = DeepCopy(v) end
        if ns.settingsTestHooks.afterCopy then ns.settingsTestHooks.afterCopy(module, store) end
        local diff
        for k, v in pairs(copied) do diff = diff or Differs(v, store[k], k) end
        if not diff and guard and guard.check then
            local ok, d = pcall(guard.check, old, store)
            if not ok then diff = "check failed: " .. tostring(d) else diff = d end
        end
        if diff then
            for k in pairs(copied) do store[k] = nil end   -- the copy is taken out again; CueRulesDB stays the place
            local mm = type(store.migrationMismatch) == "table" and store.migrationMismatch or {}
            mm.at, mm.by, mm.diff = Stamp(), st.addon .. " " .. (Meta(st.addon, "Version") or "?"), tostring(diff):sub(1, 300)
            mm.tries = (tonumber(mm.tries) or 0) + 1
            store.migrationMismatch = mm
            if not mm.reported then   -- told once (the record keeps every try)
                mm.reported = true
                local title = Meta(st.addon, "Title") or st.addon
                local text = ("%s: the settings could not be copied to their new saved place unchanged, so they stay where they were. Nothing was changed or lost."):format(title)
                if ns.Print then pcall(ns.Print, text) end
                if ns.RecordWarn then pcall(ns.RecordWarn, "XUI-W006", title .. ": " .. mm.diff) end
            end
            return "old"
        end
        store.migratedFrom = "CueRulesDB"
        store.migratedAt = Stamp()
        store.migratedBy = st.addon .. " " .. (Meta(st.addon, "Version") or "?")
        store.migratedKeys = n
        copiedNow[module] = true
    end
    store.storeVersion = 1
    return "own"
end

-- Opens a module's store (once; later calls return the state). The Platform calls it at the module addon's ADDON_LOADED (below); a
-- module whose own start-up runs at its ADDON_LOADED (XayaUI Rules) calls it first itself. Returns "own" or "old".
function ns.SettingsOpen(module)
    if not SETTINGS_STORES[module] then return nil end
    if storeState[module] then return storeState[module] end
    local ok, state = pcall(OpenStore, module)
    if not ok then Report(state); state = "old" end   -- an error while copying: keep CueRulesDB (nothing was taken from it)
    storeState[module] = state
    StoreOf(module)
    ns.settingsEpoch = ns.settingsEpoch + 1
    local queue = readyFor[module] or {}
    readyFor[module] = nil
    for _, fn in ipairs(queue) do Call(fn) end
    return state
end
-- run fn once this module's settings can be read (its store is open), at once when they already can; never while the module is off.
-- A module without its own store waits for the Platform's saved settings (ns.WhenReady).
function ns.WhenSettingsReady(module, fn)
    if type(fn) ~= "function" then return end
    if not OWN_STORE[module] then return ns.WhenReady(fn) end
    if storeState[module] then Call(fn); return end
    local q = readyFor[module] or {}
    q[#q + 1] = fn
    readyFor[module] = q
end
-- (tests that load single files without the game's loader, where no module addon fires ADDON_LOADED) open every store as the addons'
-- ADDON_LOADED would, after the test has set CueRulesDB up
function ns.SettingsOpenAllForTests() for m in pairs(SETTINGS_STORES) do ns.SettingsOpen(m) end end
-- (tests) CueRulesDB.ui as laid out before P5: a key a module took out of ui (LEGACY_UNDER_UI) goes to that module's view while its store
-- is open, every other key to the Platform's ui (for tests that set settings up by writing CueRulesDB.ui.<key>)
function ns.SettingsUiRoutedForTests()
    local function home(k)
        for m, keys in pairs(LEGACY_UNDER_UI) do if keys[k] and OWN_STORE[m] and storeState[m] == "own" then return settingsViews[m] end end
        local p = settingsViews.platform
        if type(p.ui) ~= "table" then p.ui = {} end
        return p.ui
    end
    return setmetatable({}, { __index = function(_, k) return home(k)[k] end, __newindex = function(_, k, v) home(k)[k] = v end })
end
-- (tests) a table that reads and writes every settings key through the view of the module that owns it (where the module reads it
-- now: its own store or CueRulesDB), for tests that set settings up by writing CueRulesDB.<key>; characterReskin goes to QoL's view
function ns.SettingsRoutedForTests()
    local owner = {}
    for _, m in ipairs({ "platform", "core", "chat", "bonus", "qol", "reskin", "devassist" }) do
        for _, k in ipairs(SETTINGS_KEYS[m]) do if owner[k] == nil then owner[k] = m end end
    end
    return setmetatable({}, {
        __index = function(_, k) return settingsViews[owner[k] or "platform"][k] end,
        __newindex = function(_, k, v) settingsViews[owner[k] or "platform"][k] = v end,
    })
end

-- called by XayaUI's own start-up frame (Core.lua) at every addon's ADDON_LOADED until the login: opens the store of the module that
-- addon is (no frame of its own here)
function ns.SettingsAddonLoaded(name)
    for m, st in pairs(SETTINGS_STORES) do if st.addon == name then ns.SettingsOpen(m) end end
end

-- (P5) a key of CueRulesDB as it was laid out before the stores (ui with the keys modules took out of it, characterReskin with both
-- halves), read from where each part lives now: what a settings profile part saved before P5, so profile strings stay byte-identical.
-- A part whose module is off (store not open) is left out.
local function LegacyHomes(key)
    local homes = {}
    if key == "ui" then
        local moved = {}   -- the Platform's CueRulesDB.ui still holds the old copies of these (copy, never move): never read from there
        homes[#homes + 1] = { module = "platform", key = "ui", skip = moved }
        for m, keys in pairs(LEGACY_UNDER_UI) do
            if OWN_STORE[m] and storeState[m] ~= "old" then
                for k in pairs(keys) do moved[k] = true; homes[#homes + 1] = { module = m, key = k, sub = k } end
            end
        end
        return homes
    end
    local split = LEGACY_SPLIT[key]
    if split then
        homes[#homes + 1] = { module = split.rest, key = key, skip = split.sub }
        homes[#homes + 1] = { module = split.owner, key = key, only = split.sub }
        return homes
    end
    for m, keys in pairs(SETTINGS_KEYS) do
        for _, k in ipairs(keys) do
            if k == key and not (LEGACY_UNDER_UI[m] or {})[k] then homes[#homes + 1] = { module = m, key = k }; return homes end
        end
    end
    return homes
end
local function LegacyKeep(h, kk) return not ((h.skip and h.skip[kk]) or (h.only and not h.only[kk])) end
-- a copy of CueRulesDB[key] as it would be laid out before P5 (nil when nothing is there)
function ns.SettingsLegacyGet(key)
    local homes = LegacyHomes(key)
    if #homes == 1 then local v = settingsViews[homes[1].module][homes[1].key]; return DeepCopy(v) end
    local out
    for _, h in ipairs(homes) do
        local v = settingsViews[h.module][h.key]
        if v ~= nil then
            if h.sub then
                out = out or {}
                out[h.sub] = DeepCopy(v)
            elseif type(v) == "table" then
                out = out or {}
                for kk, x in pairs(v) do if LegacyKeep(h, kk) then out[kk] = DeepCopy(x) end end
            end
        end
    end
    return out
end
-- a key that may only be true (reskinTabOff), set true in its owner's settings
function ns.SettingsLegacySetBool(key)
    local h = LegacyHomes(key)[1]
    if h and ns.SettingsReady(h.module) then settingsViews[h.module][h.key] = true end
end
-- merges a saved value into CueRulesDB[key]'s old layout, field by field where each field lives now (a settings profile part's "merge":
-- each field of `value` replaces yours); fields whose module is off are left out
function ns.SettingsLegacyMerge(key, value)
    if type(value) ~= "table" then return end
    local homes = LegacyHomes(key)
    local sub = {}
    for _, h in ipairs(homes) do if h.sub then sub[h.sub] = h end end
    for kk, vv in pairs(value) do
        local h = sub[kk]
        if h then
            if ns.SettingsReady(h.module) then settingsViews[h.module][h.key] = DeepCopy(vv) end
        else
            for _, w in ipairs(homes) do
                if not w.sub and LegacyKeep(w, kk) and ns.SettingsReady(w.module) then
                    local view = settingsViews[w.module]
                    local mine = view[w.key]
                    if type(mine) ~= "table" then mine = {}; view[w.key] = mine end
                    mine[kk] = DeepCopy(vv)
                    break
                end
            end
        end
    end
end

-- 0. Spacing every XayaUI window and pane uses (#351; Xaya, 2026-11-03: "set a standard gutter and margin so that all elements are
-- not smushed directly into their container bounds"). UI_MARGIN: the least space between a container's edge (below its title row)
-- and what is inside it. UI_GUTTER: the least space between two controls side by side. Defined here once, in core, so every addon
-- has them (each one depends on XayaUI). Windows that already leave more room keep it; segmented rows (tabs, filter buttons, icon
-- toolbars) keep their 2 px seams; title-bar close buttons and corner resize grips sit at the edge, as in Blizzard's windows.
-- (core 0.6.58; REQUEST-LOG UI-47, Xaya 2026-11-06: "make sure every single display type is correctly standardized ... refactor all
-- code appropriately") ns.Style: the one place for the numbers every XayaUI window and settings page lays itself out with. The rules
-- and her words behind each value: docs/design/DISPLAY-RULES.md (section C lists these keys) and docs/design/DISPLAY-RULINGS.md. A
-- window or page reads a value from here and never repeats the number. "session" = chosen by a session, not by her.
-- (Here, in Modules.lua, so every addon and every test that loads the core contract has it.)
ns.Style = {
    -- #351 [DISPLAY-RULINGS 5.1]: the least space between a container's edge and what is inside it, and between two controls side
    -- by side (10 / 10: session)
    margin = 10,
    gutter = 10,
    -- tab rows: top tabs [1.5] "32 px, 14 pt, outlined"; Rules sub-tabs [UI-45] "28 px, 12 pt, outlined" (16 px before the tab kept
    -- apart: session); section tabs inside a page [UI-48] "24 px, 11 pt, even row"
    tabTop = { h = 32, font = 14, outline = true },
    -- (UI-76, O-146, her words "make these tabs a little narrower and maybe 3-5% smaller": 4% smaller, 28 -> 27 px and 12 -> 11.5 pt;
    -- each of the four tabs 90% of its even share, the rest as equal gaps: the session's conservative reading, adjustable)
    tabSub = { h = 27, font = 11.5, outline = true, apartGap = 16, share = 0.9 },
    tabSection = { h = 24, font = 11, outline = true, minW = 60 },   -- minW: under it a row keeps AceGUI's layout (session)
    -- left pane: a child row starts this far right of where its parent's name starts [2.5] "Parent's name + 8 px"; WeakAuras-style
    -- nesting step [2.7] 8 px per level
    nest = { child = 8, level = 8 },
    -- the tick box on a left-pane row (session), the grey of an unticked feature's name [3.8, 3.9] (grey value: session)
    switch = { size = 16 },
    grey = { 0.5, 0.5, 0.5 },
    -- divider lines [6.3, 6.6]: 1 px, in the theme's pane border colour (session)
    divider = { size = 1 },
    -- trigger / cue / condition panes: everything under the header indented by this much (session)
    bodyIndent = 20,
    -- text inputs [UI-48] "Half width, two per row"
    input = { width = "half" },
}

ns.UI_MARGIN, ns.UI_GUTTER = ns.Style.margin, ns.Style.gutter   -- (the older names; kept so nothing that reads them changes)

-------------------------------------------------------------------------------
-- 1. Saved settings ready. Core.lua calls ns.FireReady() once, at XayaUI's own ADDON_LOADED, right after the saved settings are set
-- up. Anything registered before that waits in the queue (in load order); anything registered after (a sibling addon loads later
-- than XayaUI) runs at once.
-------------------------------------------------------------------------------
local readyQueue, isReady = {}, false

function ns.WhenReady(fn)
    if type(fn) ~= "function" then return end
    if isReady then Call(fn) else readyQueue[#readyQueue + 1] = fn end
end

function ns.FireReady()
    if isReady then return end
    isReady = true
    ns.SettingsChanged()   -- (Modules.lua section 0b) hot-path caches of settings tables re-read them once the saved settings are set up
    local queue = readyQueue
    readyQueue = {}
    for _, fn in ipairs(queue) do Call(fn) end
end

function ns.IsReady() return isReady end

-- 1b. Logged in (core 0.6.47). Core.lua's own start-up frame calls ns.FireLogin() once, at PLAYER_LOGIN. ns.AtLogin(fn) runs fn then, or
-- at once when it already fired. For features that must wait for the login (the game menu, other addons' services) but are switched
-- on only now and then: they ask for it only when they are on, so a feature that is off needs no frame or event of its own (V14).
local loginQueue, loggedIn = {}, false
function ns.AtLogin(fn)
    if type(fn) ~= "function" then return end
    if loggedIn then Call(fn) else loginQueue[#loginQueue + 1] = fn end
end
function ns.FireLogin()
    if loggedIn then return end
    loggedIn = true
    local queue = loginQueue
    loginQueue = {}
    for _, fn in ipairs(queue) do Call(fn) end
end
function ns.LoggedIn() return loggedIn end

-------------------------------------------------------------------------------
-- 2. /xui commands. Core's own commands stay in Core.lua; a feature adds its own here.
-------------------------------------------------------------------------------
local commands, helpText = {}, {}

function ns.RegisterCommand(names, fn, help)
    if type(fn) ~= "function" then return end
    if type(names) == "string" then names = { names } end
    for _, n in ipairs(names) do
        n = tostring(n):lower()
        commands[n] = commands[n] or {}
        table.insert(commands[n], fn)
    end
    if type(help) == "string" and help ~= "" then helpText[#helpText + 1] = help end
end

-- true when at least one registered handler took the command
function ns.RunCommand(cmd, arg)
    local list = commands[cmd]
    if not list then return false end
    for _, fn in ipairs(list) do Call(fn, arg) end
    return true
end

function ns.CommandHelp() return helpText end

-- 2b. /xui debug <name> [args] (core 0.6.50; Xaya 2026-11-05: "can't some of these be consolidated into a /xui debug _____ ? this is a
-- LOT of noise"). Diagnostic commands live under /xui debug, so /xui help lists only what a player uses. /xui debug <name> is the only
-- way to run one (Xaya 2026-11-06: "let's move to /xui debug ____"; the old /xui <name> forms were taken out the same day).
-- help: one string or a list of strings, each "name [args] (what it does)", without "/xui debug".
local debugCommands, debugHelp = {}, {}
function ns.RegisterDebugCommand(names, fn, help)
    if type(fn) ~= "function" then return end
    if type(names) == "string" then names = { names } end
    for _, n in ipairs(names) do
        n = tostring(n):lower()
        debugCommands[n] = debugCommands[n] or {}
        table.insert(debugCommands[n], fn)
    end
    if type(help) == "string" then help = { help } end
    for _, h in ipairs(type(help) == "table" and help or {}) do
        if type(h) == "string" and h ~= "" then debugHelp[#debugHelp + 1] = h end
    end
end
function ns.RunDebugCommand(cmd, arg)
    local list = debugCommands[cmd]
    if not list then return false end
    for _, fn in ipairs(list) do Call(fn, arg) end
    return true
end
function ns.DebugCommandHelp() return debugHelp end

-- 2c. Words added to a command another file owns (core 0.6.56; Xaya 2026-11-06, REQUEST-LOG #81: developer tools move to XayaUI Dev
-- Assist). slash = the owner's name for its command ("chat" for /xui chat, "xuiskin", "xuiengine"); names = one word or a list.
-- The owner asks ns.RunSubcommand before its own "unknown word" answer, so a word nobody registered does not exist. Dev Assist is the
-- only one that registers words today; without it these lists are empty and cost nothing.
local subs, subHelp = {}, {}
function ns.RegisterSubcommand(slash, names, fn, help)
    if type(slash) ~= "string" or type(fn) ~= "function" then return end
    if type(names) == "string" then names = { names } end
    subs[slash] = subs[slash] or {}
    for _, n in ipairs(names) do subs[slash][tostring(n):lower()] = fn end
    if type(help) == "string" and help ~= "" then
        subHelp[slash] = subHelp[slash] or {}
        table.insert(subHelp[slash], help)
    end
end
-- true when a registered word took it
function ns.RunSubcommand(slash, word, arg)
    local fn = subs[slash] and subs[slash][tostring(word or ""):lower()]
    if not fn then return false end
    Call(fn, arg or "")
    return true
end
-- "" when nothing is registered; else " Also: " and each help line after cmd (e.g. "/xuiskin "), joined with "; ", and "."
function ns.SubcommandList(slash, cmd)
    local h = subHelp[slash]
    if not h or #h == 0 then return "" end
    local t = {}
    for i, line in ipairs(h) do t[i] = (cmd or "") .. line end
    return " Also: " .. table.concat(t, "; ") .. "."
end
function ns.SubcommandHelp(slash) return subHelp[slash] or {} end

-- 2d. The detailed debug record's hand-in points (core 0.6.56; REQUEST-LOG #82). Core's files call these on their paths (a rule fired,
-- a sound played, a display shown, a log line) only after testing them for nil. They are nil unless XayaUI Dev Assist, which keeps the
-- detailed record, puts its functions here when it loads; nothing else may. Without it each call site costs one nil test.
local DEBUG_HOOKS = { RecordLine = true, RecordOn = true, RecTrigger = true, RecDisplay = true, RecSound = true, RecordSummary = true,
    DevRecordChanged = true }
function ns.SetDebugHooks(t)
    if type(t) ~= "table" then return end
    for k, fn in pairs(t) do
        if DEBUG_HOOKS[k] and type(fn) == "function" then ns[k] = fn end
    end
end

-------------------------------------------------------------------------------
-- 3. Which addon owns what. Only used for messages and the Addon Info status list; nothing here is called.
-------------------------------------------------------------------------------
ns.MODULES = {
    -- (core 0.6.56: chatprobe and widthprobe are XayaUI Dev Assist's now, REQUEST-LOG #81; without it they do not exist)
    { addon = "XayaUI_Chat",    title = "XayaUI Chat",            commands = { "chat", "panel", "privacy" } },
    -- (core 0.6.67, audit D8) every word these addons register, so "/xui shop" with QoL off says to turn QoL on (USER-GUIDE section 0)
    { addon = "XayaUI_QoL",     title = "XayaUI QoL",             commands = { "cursor", "stats", "shop", "reskin", "releaseguard", "rg" } },
    { addon = "XayaUI_Bonus",   title = "XayaUI Bonus Features",  commands = { "notes", "notepad", "note", "data", "calc", "calculator" } },
    { addon = "XayaUI_Reskin",  title = "XayaUI Blizzard Reskin", commands = {} },
    { addon = "XayaUI_Options", title = "XayaUI Options",         commands = {} },
    -- (P4) rule and aura tracking: the commands Core.lua keeps for it (unlock, status, perf, talents) and AuraList.lua's auras
    { addon = "XayaUI_Rules",   title = "XayaUI Rules",           commands = { "unlock", "status", "auras" }, debug = { "status", "perf", "talents", "auras" },
      sharePrefixes = { "XUI1" } },   -- (its share kind: a rules string pasted while it is off says it needs this addon; Share.lua)
}

-- isDebug: look in the /xui debug names (m.debug) instead of the /xui names (core 0.6.50)
function ns.ModuleOfCommand(cmd, isDebug)
    for _, m in ipairs(ns.MODULES) do
        for _, c in ipairs((isDebug and m.debug or m.commands) or {}) do if c == cmd then return m end end
    end
end

-- "loaded", "disabled", "missing", or "unknown" (game API not available). Wrapped: C_AddOns can refuse odd names.
function ns.ModuleState(addon)
    local A = C_AddOns
    if not A then return "unknown" end
    local okL, loaded = pcall(A.IsAddOnLoaded, addon)
    if okL and loaded then return "loaded" end
    local okI, name, _, _, _, reason = pcall(A.GetAddOnInfo, addon)
    if not okI then return "unknown" end
    if reason == "MISSING" or not name then return "missing" end
    return "disabled"
end

-- One line explaining why a command did nothing. Until a feature has moved out of the XayaUI folder its addon does not exist yet,
-- so "missing" there means the feature's own file failed to load.
function ns.ModuleMissingText(cmd, isDebug)
    local m = ns.ModuleOfCommand(cmd, isDebug)
    if not m then return nil end
    if isDebug then cmd = "debug " .. cmd end
    local state = ns.ModuleState(m.addon)
    if state == "disabled" then
        return ("/xui %s is part of %s, which is switched off. Turn it on in the game's AddOns list, then /reload."):format(cmd, m.title)
    elseif state == "missing" then
        return ("/xui %s is part of %s, which is not installed (or its files failed to load; /xui bug shows errors)."):format(cmd, m.title)
    end
    return ("/xui %s did not respond: %s is loaded, but the command was never registered. /xui bug shows errors."):format(cmd, m.title)
end

-------------------------------------------------------------------------------
-- 4. Minimap button list. entry = { key, label, tooltip, action, stateFn (optional), order = number, available = fn (optional) }
-- Positional fields keep MinimapButton.lua's row code unchanged. Lower order is higher in the list.
-- available (core 0.6.49): a function that returns false while the entry's feature is switched off; the list then leaves the row out
-- (V14: a switched-off feature shows no row; first user: the Character Toolkit's Stat Calculator row, QoL 0.7.23). The entry stays
-- registered, so the settings window's options tree is the same with the feature on and off (a sidebar tick reuses the drawn tree,
-- tests/sidebar_switches_run.py); its row on Settings > Minimap Button is hidden instead.
-------------------------------------------------------------------------------
local launchers = {}

function ns.RegisterLauncher(entry)
    if type(entry) ~= "table" or type(entry[1]) ~= "string" or type(entry[4]) ~= "function" then return end
    for i, e in ipairs(launchers) do
        if e[1] == entry[1] then launchers[i] = entry; return end   -- same key again (a second copy of a file): replace, never duplicate
    end
    launchers[#launchers + 1] = entry
    table.sort(launchers, function(a, b)
        local oa, ob = tonumber(a.order) or 100, tonumber(b.order) or 100
        if oa ~= ob then return oa < ob end
        return a[1] < b[1]
    end)
end

function ns.Launchers() return launchers end

-------------------------------------------------------------------------------
-- 5. Settings pages. module = "chat", "qol", "bonus", "reskin" (which tab the page belongs to), key = the page's key inside it.
-- The settings window calls build(Notify) every time it rebuilds its tree.
-------------------------------------------------------------------------------
local pages = {}

function ns.RegisterSettingsPage(module, key, build)
    if type(key) ~= "string" or type(build) ~= "function" then return end
    for i, p in ipairs(pages) do
        if p.key == key then pages[i] = { module = module, key = key, build = build }; return end
    end
    pages[#pages + 1] = { module = module, key = key, build = build }
end

-- The Blizzard UI Reskin tab's own switch (core 0.6.51, S1 #48; Xaya 2026-11-05: "double: both enable/disable of reskin at all; then individual
-- toggles for individual reskins"). Off turns every reskin off (Chat Panel, Character Pane, Esc Menu, Shopping List) and each keeps its
-- own switch for when the tab is on again. Saved only while off (CueRulesDB.reskinTabOff = true), so a profile that never touched it
-- holds nothing. Every reskin reads it with its own switch: on = its own switch AND this one.
function ns.ReskinTabOn() return not (type(CueRulesDB) == "table" and CueRulesDB.reskinTabOff) end
-- Each reskin registers its own apply (it builds, or gives Blizzard's look back) with ns.RegisterReskin(key, fn), the way features
-- register everything else here; core only walks the list. A reskin whose addon is off is simply not in it.
local reskins = {}
function ns.RegisterReskin(key, apply) if type(key) == "string" and type(apply) == "function" then reskins[key] = apply end end
-- Set it and let every registered reskin take it at once (in key order, each through pcall).
function ns.SetReskinTab(on)
    if type(CueRulesDB) ~= "table" then return end
    CueRulesDB.reskinTabOff = (not on) and true or nil
    local keys = {}
    for k in pairs(reskins) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do Call(reskins[k]) end
end

-- Page layout for every feature tab (Xaya, 2026-11-03; QoL and Chat first, the rule for new features):
--   * a feature is a node in the left pane; its parts are child nodes under it (the feature's group has childGroups = "tree"),
--     and the feature's own node shows its overview (on/off switches, a short note);
--   * inside one part, its sections are tabs.
-- ns.SectionTabs(group) gives a part that shape from a flat list: everything before the first header stays above the tabs, and
-- each header becomes a tab holding the entries up to the next header. The header's desc becomes the tab's first line and its
-- hidden carries over. The group is changed in place and returned; a group without headers is returned unchanged.
function ns.SectionTabs(group)
    local args = type(group) == "table" and group.args
    if type(args) ~= "table" then return group end
    local function ord(e)
        local o = e.order
        if type(o) == "function" then local ok, v = pcall(o); o = ok and v or nil end
        return tonumber(o) or 100
    end
    local heads = {}
    for k, e in pairs(args) do
        if type(e) == "table" and e.type == "header" then heads[#heads + 1] = { key = k, e = e, o = ord(e) } end
    end
    if #heads == 0 then return group end
    table.sort(heads, function(a, b) if a.o ~= b.o then return a.o < b.o end return tostring(a.key) < tostring(b.key) end)
    local tabs = {}
    for i, h in ipairs(heads) do
        tabs[i] = { type = "group", name = h.e.name, order = h.o, hidden = h.e.hidden, args = {} }
        if h.e.desc ~= nil and h.e.desc ~= "" then
            tabs[i].args.sectionNote = { type = "description", order = h.o - 0.001, width = "full", fontSize = "medium", name = h.e.desc }
        end
    end
    local moves = {}
    for k, e in pairs(args) do
        if type(e) == "table" and e.type ~= "header" then
            local o, at = ord(e), nil
            for i = #heads, 1, -1 do if heads[i].o <= o then at = i; break end end
            if at then moves[#moves + 1] = { k = k, at = at } end
        end
    end
    for _, m in ipairs(moves) do
        local dest = tabs[m.at].args
        local key = (m.k == "sectionNote") and "sectionNote2" or m.k
        dest[key] = args[m.k]; args[m.k] = nil
    end
    for i, h in ipairs(heads) do
        args[h.key] = nil
        args["tab_" .. tostring(h.key)] = tabs[i]
    end
    group.childGroups = "tab"
    return group
end

-- A page's summary with an info icon that opens / closes the page's full description in a box (core 0.6.61; REQUEST-LOG UI-53, her
-- answer: "isolated to an info icon that opens/closes a description box -- try this out for one text-heavy segment and confirm POC
-- before proceeding for all"; first used on Bonus Features > Utilities > Calculator only, until she confirms).
-- ns.InfoBox(group, id, summary, keys): the page shows `summary` (up to two sentences, UI-53) with the icon beside it; the description
-- entries named in `keys` move into a box under it, shown while the icon is toggled open (closed at first; kept for the session).
ns.infoBoxOpen = ns.infoBoxOpen or {}
function ns.InfoBox(group, id, summary, keys)
    local args = type(group) == "table" and group.args
    if type(args) ~= "table" then return group end
    local box = { type = "group", inline = true, name = "Description", order = 0.03, args = {},   -- (a titled inline group: AceConfigDialog draws an untitled one with no box)
        hidden = function() return not ns.infoBoxOpen[id] end }
    for i, k in ipairs(keys) do
        local e = args[k]
        if type(e) == "table" then
            e.order = i
            e.arg = type(e.arg) == "table" and e.arg or {}
            e.arg.xuiKeep = true   -- (not folded into a heading's (i) by the settings window's info pass)
            box.args[k] = e
            args[k] = nil
        end
    end
    args.xuiSummary = { type = "description", order = 0.01, width = "relative", relWidth = 0.88, fontSize = "medium", name = summary,
        arg = { xuiKeep = true } }
    args.xuiInfoToggle = { type = "execute", order = 0.02, width = "relative", relWidth = 0.1, name = "Description",
        desc = function() return ns.infoBoxOpen[id] and "Hides this page's full description." or "Shows this page's full description." end,
        image = "Interface\\common\\help-i", imageWidth = 22, imageHeight = 22, arg = { xuiInfoToggle = true },
        func = function() ns.infoBoxOpen[id] = not ns.infoBoxOpen[id] or nil; if ns.Fire then ns.Fire("CONFIG_CHANGED") end end }
    args.xuiInfoBox = box
    return group
end

-- { [key] = group } for every page of one module (or of all modules when module is nil). A page whose builder errors is skipped.
function ns.BuildSettingsPages(module, Notify)
    local out = {}
    for _, p in ipairs(pages) do
        if module == nil or p.module == module then
            local ok, group = pcall(p.build, Notify)
            if ok and type(group) == "table" then out[p.key] = group elseif not ok then Report(group) end
        end
    end
    return out
end

-------------------------------------------------------------------------------
-- 6. Messages between XayaUI's own parts (not game events). The sender never needs the receiver to exist: the settings window
-- is in a load-on-demand addon and may never be loaded in a session.
--   CONFIG_CHANGED (what)  settings or rules changed outside the window (a drag on screen, a command, an import): redraw if open.
--                    what = "view": only a switch's state changed (nothing in the options tree), so the redraw may reuse the tree
--   LOG (line)       a line for the debug console
--   THEME_CHANGED    the theme changed: re-skin open windows
--   EDITED           ns.MarkDirty ran (the window's undo journal listens)
-------------------------------------------------------------------------------
local listeners = {}
function ns.On(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then return end
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], fn)
end
function ns.Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for _, fn in ipairs(list) do Call(fn, ...) end
end

-------------------------------------------------------------------------------
-- 7. The settings window. Its code is the addon XayaUI_Options, which the game loads only when asked (## LoadOnDemand). Everything
-- outside it opens the window through these functions, so nothing else needs to know whether it is loaded yet. XayaUI_Options
-- fills in ns.Options = { Toggle, EditRule, OpenPage, IconReport, IsOpen, SkinOn } when it loads.
-------------------------------------------------------------------------------
ns.OPTIONS_ADDON = "XayaUI_Options"
local optionsWarned
function ns.LoadOptions()
    if ns.Options then return true end
    if not isReady then ns.Print("saved settings are not ready yet; try again in a moment."); return false end
    local A = C_AddOns
    if not (A and A.LoadAddOn) then return false end
    local ok, loaded, reason = pcall(A.LoadAddOn, ns.OPTIONS_ADDON)
    if ok and loaded and ns.Options then
        -- (XayaUI 0.6.77, P4b) the window's own parts that are separate load-on-demand addons (the rule editor, XayaUI_Rules_Options,
        -- while XayaUI Rules is on) load now, after XayaUI_Options has finished loading; the window decides which (ns.Options.AfterLoad)
        if ns.Options.AfterLoad then Call(ns.Options.AfterLoad) end
        return true
    end
    if not optionsWarned then
        optionsWarned = true
        local state = ns.ModuleState(ns.OPTIONS_ADDON)
        if state == "disabled" then
            ns.Print("the settings window (XayaUI Options) is switched off in the game's AddOns list. Turn it on, then /reload.")
        elseif state == "missing" then
            ns.Print("the settings window (XayaUI Options) is not installed: the XayaUI_Options folder belongs next to XayaUI in Interface\\AddOns.")
        else
            ns.Print("the settings window could not load (" .. tostring(ok and reason or loaded) .. "). /xui bug shows errors.")
        end
    end
    return false
end
function ns.ToggleUI() if ns.LoadOptions() then ns.Options.Toggle() end end
function ns.EditRule(rule) if rule and ns.LoadOptions() then ns.Options.EditRule(rule) end end
function ns.EditFolder(f) if f and ns.LoadOptions() and ns.Options.EditFolder then ns.Options.EditFolder(f) end end
-- module = "chat" | "qol" | "bonus" | "reskin" | "core"; key = the page registered with ns.RegisterSettingsPage; sub = a tab inside it
-- ... = the path below the page: a part (left-pane child node) and/or a tab, e.g. ("chat", "chatpanel", "bar", "tab_blocksHdr")
function ns.OpenSettingsPage(module, key, ...) if ns.LoadOptions() then ns.Options.OpenPage(module, key, ...) end end
function ns.IsOptionsOpen() return ns.Options and ns.Options.IsOpen and ns.Options.IsOpen() or false end

-- The game's own Options > AddOns list gets an entry that opens the real window, and the addon compartment (the minimap "addons"
-- menu) calls XayaUI_OnCompartmentClick (named in XayaUI.toc). Both live here so they work before the window's code is loaded.
local function RegisterBlizzardPanel()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory and CreateFrame) then return end
    local panel = CreateFrame("Frame")
    panel.name = "XayaUI"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("XayaUI")
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    sub:SetWidth(560)
    sub:SetJustifyH("LEFT")
    sub:SetText("Sound cues and on-screen alerts driven by rules: buff, cooldown, talent, and conditions.\nSlash commands: /xui (or /xayaui)  |  /xui status  |  /xui report  |  /xui unlock")
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(200, 28)
    btn:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -20)
    btn:SetText("Open XayaUI")
    btn:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then
            if ns.MapTrace then ns.MapTrace("core: HideUIPanel(SettingsPanel)") end
            if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
        end
        if not ns.IsOptionsOpen() then ns.ToggleUI() end
    end)
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "XayaUI")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
        ns.settingsCategory = category
    end
end
Call(RegisterBlizzardPanel)
function XayaUI_OnCompartmentClick() ns.ToggleUI() end

-- /xuiskin: the settings window's flat look on or off (read by XayaUI_Options when the window opens). core 0.6.56 (Xaya 2026-11-06,
-- REQUEST-LOG #81: "move pad and alpha to dev"): "/xuiskin pad N" and "/xuiskin alpha X" are XayaUI Dev Assist's (registered with
-- ns.RegisterSubcommand("xuiskin", ...), XayaUI_DevAssist/CoreDebug.lua); without it they do not exist and the command says what it does.
SLASH_XUISKIN1 = "/xuiskin"
if type(SlashCmdList) == "table" then SlashCmdList["XUISKIN"] = function(msg)
    if not CueRulesDB then return end
    CueRulesDB.ui = CueRulesDB.ui or {}
    local word, rest = tostring(msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if word ~= "" then
        if not ns.RunSubcommand("xuiskin", word, rest) then
            print("|cffffd100XayaUI|r /xuiskin switches the settings window's skin on or off (type it without anything after it)."
                .. ns.SubcommandList("xuiskin", "/xuiskin "))
        end
        return
    end
    CueRulesDB.ui.skinOff = (not CueRulesDB.ui.skinOff) or nil
    print("|cffffd100XayaUI|r window skin " .. (CueRulesDB.ui.skinOff and "OFF" or "ON") .. " - type /reload to apply.")
end
end

-------------------------------------------------------------------------------
-- 8. Services: a feature that answers questions for others registers an object under a name; the asker gets nil when that feature
-- is switched off. Today: "gameMenuSkin" (XayaUI_Reskin) answers Active() and MatchReal() for the ESC-menu button (GameMenuButton.lua);
-- (UI-77, core 0.6.68: the "buttonSkin" service is gone; the flat button look is core's own, Core.lua ns.PaintFlatButton.)
-------------------------------------------------------------------------------
local services = {}
function ns.Provide(name, obj) if type(name) == "string" and type(obj) == "table" then services[name] = obj end end
function ns.Service(name) return services[name] end
-- Is XayaUI Dev Assist (the separate developer addon, folder XayaUI_DevAssist) loaded? It sets ns.devAssistLoaded when its first file
-- runs (core 0.6.56; REQUEST-LOG #81: the developer tools are there, and the Aura ID "via ..." text shows only while it is on).
function ns.DevAssistOn() return ns.devAssistLoaded == true end
-- /xui dev qa: the QA walkthroughs live in the developer add-on, which registers its own "dev" handler. While that add-on is off, this
-- says how to get them (core finds the add-on only through its service, "gameDataProbe": core 0.6.55)
ns.RegisterCommand({ "dev", "qa", "qatest" }, function()   -- (/xui qa test and /xui qatest: Xaya's aliases, FUS-9)
    if not services.gameDataProbe and ns.Print then
        ns.Print("the QA walkthroughs are part of XayaUI Dev Assist: switch it on in the AddOns list (character select or Esc > AddOns), then /reload and type /xui dev qa again.")
    end
end)

-------------------------------------------------------------------------------
-- 8b. Tooltips: one helper draws XayaUI's own hover texts (core 0.6.73; REQUEST-LOG UI-51 / UI-52, BUILD-RULES.md B3: "one shared
-- helper draws every XayaUI tooltip"; order UI-55 "Baseline, refactor, test"). It only forwards to GameTooltip, in the same order
-- the units called it before, so no tooltip changes (tests/tooltip_parity_run.py records every call before and after). No state,
-- no frames, no events: it costs nothing until something is hovered. Game-object tooltips (SetSpellByID, SetItemByID, ...) stay
-- direct calls.
--   ns.Tip.Show(owner, anchor, title, lines)
--     title: "text" -> SetText(text); { text, r, g, b } -> SetText(text, r, g, b); { text, r, g, b, add = true } -> AddLine(...)
--     lines: list of "text" -> AddLine(text), or { text, r, g, b, wrap } -> AddLine(text, r, g, b, wrap)
--   ns.Tip.Hide()
-------------------------------------------------------------------------------
ns.Tip = ns.Tip or {}
local function TipLine(tip, l, set)
    if type(l) == "table" then
        if set and not l.add then
            if l[2] ~= nil then tip:SetText(l[1], l[2], l[3], l[4]) else tip:SetText(l[1]) end
        elseif l[5] ~= nil then tip:AddLine(l[1], l[2], l[3], l[4], l[5])
        elseif l[2] ~= nil then tip:AddLine(l[1], l[2], l[3], l[4])
        else tip:AddLine(l[1]) end
    elseif l ~= nil then
        if set then tip:SetText(l) else tip:AddLine(l) end
    end
end
function ns.Tip.Show(owner, anchor, title, lines)
    local tip = GameTooltip
    if not tip then return end
    tip:SetOwner(owner, anchor)
    if title ~= nil then TipLine(tip, title, true) end
    if type(lines) == "table" then for i = 1, #lines do TipLine(tip, lines[i], false) end end
    tip:Show()
end
function ns.Tip.Hide() if GameTooltip then GameTooltip:Hide() end end

-------------------------------------------------------------------------------
-- 9. The world map report: /xui debug map (core 0.6.49; REQUEST-LOG #30, Xaya 2026-11-05: "map eclipses full screen" [the Silvermoon
-- world map full screen], 2026-11-06: it happens "only with XayaUI on"). NOT a fix: the cause was not found offline (debug log of QoL
-- 0.7.24). What decides it in Blizzard's code (12.1.5 source, read 2026-11-06): the map opens maximized (full screen, black around it)
-- when QuestLogOwnerMixin:ShouldBeMinimized() is false: `C_GameRules.IsGameRuleActive(Enum.GameRule.MaximizeWorldMapDisabled) or
-- GetCVarBool("miniWorldMap")` (Blizzard_WorldMap/QuestLogOwnerMixin.lua:194-198); its OnShow maximizes or minimizes to match the CVar
-- (Blizzard_WorldMap.lua:365-372); maximizing calls MaximizeUIPanel and sizes the map from its parent's size (Blizzard_WorldMap.lua:
-- 18-23, 438-455). No XayaUI file sets that CVar or calls a world map function (git grep: SetCVar only for the four volume CVars in
-- Sound.lua). XayaUI's only calls into Blizzard's panel manager are counted here (ns.MapTrace) so the report says which ran since login.
-- API (docs/reference/api): C_CVar.GetCVar(name: cstring) -> value: string? · SecretArguments=NotAllowed (namespaces.md:584);
-- C_GameRules.IsGameRuleActive(gameRule: GameRule) -> isActive: bool · SecretArguments=AllowedWhenUntainted (namespaces.md:1926);
-- Enum.GameRule.MaximizeWorldMapDisabled = 67 (enums.md:5681); GetSize(ignoreRect: bool = false) -> width, height · ConstSecretAccessor,
-- SecretWhenAnchoringSecret; GetEffectiveScale() -> effectiveScale · SecretReturnsForAspect=[Scale]; GetScale(); IsShown() (widgets.md).
-- INFERENCE (Blizzard's Lua, not API documentation): WorldMapFrame:IsMaximized() (Blizzard_WorldMap.lua:117) and GetUIPanel(key)
-- (UIParentPanelManager.lua:918). Every read is pcall'd; a secret or missing answer prints "?". Nothing here runs until typed; the
-- counter is one table write per call it counts.
-------------------------------------------------------------------------------
local mapTrace, mapOrder = {}, {}
function ns.MapTrace(name)
    local t = mapTrace[name]
    if not t then t = { n = 0 }; mapTrace[name] = t; mapOrder[#mapOrder + 1] = name end
    t.n = t.n + 1
    t.last = GetTime and GetTime() or 0
end
function ns.MapTraceCounts() return mapTrace end   -- (tests)
function ns.MapTraceOrder() return mapOrder end
-- (core 0.6.56; REQUEST-LOG #81, Xaya 2026-11-06 "Move all of them": the report itself, /xui debug map, is in XayaUI Dev Assist,
-- XayaUI_DevAssist/CoreDebug.lua; the counter above stays, as XayaUI's own calls are counted whether or not Dev Assist is there)

-------------------------------------------------------------------------------
-- 9. Profile parts (core 0.6.74; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.1, PS-6, Xaya 2026-11-07: "Does sharer / import /
-- export have "universal plumbing" configured for each model to tie into? If not, it should — it should support sharing across all
-- modules a user has installed."). Each module registers the part of a profile (Profiles > Import / Export, XayaUI_Options/Profiles.lua)
-- it owns; Profiles only walks this list. A module that is switched off registers nothing, so its part is not offered; a pasted profile
-- keeps the part and Import says "needs <addon title>".
--   ns.RegisterProfilePart{ key, label, module, snapshot(name) -> table, apply(data, mode, fromVersion) -> result,
--       check(data) -> clean table or nil, describe(data) -> text (optional), never = {...}, version = 1, order = number,
--       reload = false (the part takes effect without a reload; default: a reload puts it to work) }
--   or, for a part that is a list of CueRulesDB keys (every settings part today): db = { keys }, bools = { [key] = true } (a key that
--   may only be true), and the Platform builds snapshot / check / apply exactly as Profiles.lua did before 0.6.74:
--     snapshot: a copy of each key, without keys starting with "_" and without what `never` names;
--     apply (mode "merge", the only settings mode today): each saved value in the profile replaces yours; values the profile does not
--       have stay as they are.
--   never = { [sub key] = true (left out) | "name" (that sub-table's field "name" left out) | { ... } (the same rules one level down) }.
-- Every snapshot / check / apply runs through pcall (one module's error never stops another's part).
-------------------------------------------------------------------------------
local profileParts, profilePartByKey = {}, {}

local function StripUnderscore(t, depth)
    if type(t) ~= "table" or depth > 16 then return end
    for k, v in pairs(t) do
        if type(k) == "string" and k:sub(1, 1) == "_" then t[k] = nil
        elseif type(v) == "table" then StripUnderscore(v, depth + 1) end
    end
end
-- removes what `never` names from t (in place); returns t
local function StripNever(t, never, depth)
    if type(t) ~= "table" or type(never) ~= "table" or (depth or 1) > 16 then return t end
    for k, how in pairs(never) do
        if how == true then t[k] = nil
        elseif type(how) == "string" and type(t[k]) == "table" then t[k][how] = nil
        elseif type(how) == "table" and type(t[k]) == "table" then StripNever(t[k], how, (depth or 1) + 1) end
    end
    return t
end
ns.ProfileStripNever = StripNever
-- one saved table as it goes into a profile: no "_" keys, nothing `never` names (sub rules for this key)
local function StripDbTable(v, never)
    if type(v) ~= "table" then return v end
    StripUnderscore(v, 1)
    if type(never) == "table" then
        for k, how in pairs(never) do
            if how == true then v[k] = nil
            elseif type(how) == "string" and type(v[k]) == "table" then v[k][how] = nil
            elseif type(how) == "table" and type(v[k]) == "table" then StripNever(v[k], how, 2) end
        end
    end
    return v
end

local function DbPart(def)
    local keys, bools, never = def.db, def.bools or {}, def.never or {}
    def.snapshot = def.snapshot or function()
        local part = {}
        for _, k in ipairs(keys) do
            -- (P5) the key as CueRulesDB laid it out before the module stores, read from where each part lives now (section 0c), so a
            -- profile string is byte-for-byte what it was
            local v = ns.SettingsLegacyGet(k)
            if v ~= nil then part[k] = StripDbTable(v, never[k]) end
        end
        return part
    end
    def.check = def.check or function(part)
        local cp = {}
        for _, k in ipairs(keys) do
            local v = part[k]
            if bools[k] then cp[k] = (v == true) or nil
            elseif type(v) == "table" then cp[k] = StripDbTable(v, never[k]) end
        end
        return cp
    end
    def.apply = def.apply or function(part)
        if not ns.SettingsReady() then return nil end
        for _, k in ipairs(keys) do
            local v = part[k]
            if bools[k] then
                if v == true then ns.SettingsLegacySetBool(k) end
            elseif type(v) == "table" then
                ns.SettingsLegacyMerge(k, v)   -- (P5) each field into the store of the module that owns it now; a module that is off: left out
            end
        end
        ns.SettingsChanged()   -- (Modules.lua section 0b) a key may be a new table now: hot-path caches re-read it
        return { reload = true }
    end
    return def
end

function ns.RegisterProfilePart(def)
    local ok, err = pcall(function()
        if type(def) ~= "table" or type(def.key) ~= "string" or def.key == "" or type(def.label) ~= "string" then return end
        if type(def.db) == "table" then DbPart(def) end
        if type(def.snapshot) ~= "function" or type(def.apply) ~= "function" then return end
        def.version = tonumber(def.version) or 1
        def.check = def.check or function(part) return part end
        local old = profilePartByKey[def.key]
        if old then for i, p in ipairs(profileParts) do if p == old then table.remove(profileParts, i); break end end end
        profileParts[#profileParts + 1] = def
        profilePartByKey[def.key] = def
        table.sort(profileParts, function(a, b)
            local oa, ob = tonumber(a.order) or 100, tonumber(b.order) or 100
            if oa ~= ob then return oa < ob end
            return a.key < b.key
        end)
    end)
    if not ok then Report(err) end
end
-- the registered parts in window order (a live list: the same table every time) and by key
function ns.ProfileParts() return profileParts end
function ns.ProfilePartsByKey() return profilePartByKey end
-- the title of a module's addon as the AddOns list shows it ("XayaUI Chat"), or nil
function ns.AddonTitle(addon)
    if type(addon) ~= "string" then return nil end
    for _, m in ipairs(ns.MODULES or {}) do if m.addon == addon then return m.title end end
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if get then local ok, t = pcall(get, addon, "Title"); if ok and type(t) == "string" and t ~= "" then return t end end
    return nil
end

-- The Platform's own parts (the keys live in CueRulesDB, declared by this folder). "Settings" holds the window and minimap button
-- settings. "Blizzard Reskin" holds keys of three modules (chat2 / chat: XayaUI Chat; characterReskin: XayaUI QoL; reskinTabOff: the
-- Platform's Blizzard Reskin switch, Modules.lua ns.ReskinTabOn): it stays one part, registered here where its data lives, so a profile
-- string is byte-for-byte what it was before 0.6.74 (plan 6.1 keeps Chat's keys where they are; tests/profile_parts_run.py).
ns.RegisterProfilePart({ key = "settings", label = "Settings", module = "XayaUI", order = 30, version = 1,
    db = { "ui", "minimap" },
    never = { ui = { defaultFolders = true, defaultFoldersV = true, folderOrdered = true, hybridMigrated = true, progressMigrated = true,
        infoPanePos = true, trayOpen = true, consoleOpen = true, console = true, rulesSub = true, cur = true, fwd = true,
        creatorIDs = true, recCats = true } } })
ns.RegisterProfilePart({ key = "reskin", label = "Blizzard Reskin", module = "XayaUI", order = 60, version = 1,
    db = { "chat2", "chat", "characterReskin", "reskinTabOff" }, bools = { reskinTabOff = true },
    never = { chat2 = { whisperSounds = "list" } } })   -- the per-sender whisper sounds name other players: the list is left out

-------------------------------------------------------------------------------
-- 10. Recycle Bin kinds (core 0.6.74; plan section 6.3, PS-4, Xaya 2026-11-07: "Recycle Bin can be moved to XayaUI "core" and not "rule
-- tracking," because it houses more than one type of file delete"). The bin (RecycleBin.lua) keeps the storage, the keep times and the
-- page; what an item IS comes from the kind its module registered:
--   ns.RegisterBinKind{ kind, label, describe(item) -> the page's line, restore(item) -> ok, note }
-- An item whose kind is not registered (its module is switched off) stays in the bin untouched and reads "(<kind>: module not loaded)".
-------------------------------------------------------------------------------
local binKinds = {}
function ns.RegisterBinKind(def)
    local ok, err = pcall(function()
        if type(def) ~= "table" or type(def.kind) ~= "string" or type(def.restore) ~= "function" then return end
        binKinds[def.kind] = def
    end)
    if not ok then Report(err) end
end
function ns.BinKind(kind) return binKinds[kind] end
