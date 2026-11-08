-------------------------------------------------------------------------------
-- QAWalks-settings-migration.lua (XayaUI_DevAssist 0.7.59): the in-game walkthrough for the settings migration of the platform split,
-- phase P5 (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5 steps 2-3; XayaUI 0.6.78; QA H16). Each module's settings were copied
-- once from CueRulesDB into its own saved variable (core Modules.lua sections 0b / 0c); CueRulesDB keeps the old copy untouched.
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click).
-- Two parts around a /reload:
--   part 1: per module, where its settings are read from and what the copy recorded ("copied from CueRulesDB by <addon> <version> on
--           <date>"); a few values compared, the module's own store against the old copy in CueRulesDB (a verdict only in the session
--           the copy was made: later, a value she changed is meant to differ); XayaUI Rules: rules, groups and buff bars counted on both
--           sides, and the backup made before the copy; then one marker written into one table of each module's own store;
--   part 2: after the /reload, every marker read back from the module's own store, then taken out again.
-- Reaches every module only through core (ns.Settings, ns.SettingsStore, ns.SettingsOldValue, ns.Backups). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function View(m) local ns = NS(); return ns and ns.Settings and ns.Settings(m) end
local function Store(m) local ns = NS(); return ns and ns.SettingsStore and ns.SettingsStore(m) end
local function Old(m, k) local ns = NS(); return ns and ns.SettingsOldValue and ns.SettingsOldValue(m, k) end

-- the modules, their AddOns-list titles, a few keys to compare, and the table the marker goes into
local MODS = {   -- (short: the name in the step's record, which keeps 200 characters)
    { m = "reskin",    short = "Reskin", title = "XayaUI Blizzard Reskin", keys = { "rsk", "gm", "friendColors" },                     marker = "friendColors" },
    { m = "chat", short = "Chat",      title = "XayaUI Chat",            keys = { "chat", "chat2" },                                 marker = "chat2" },
    { m = "bonus", short = "Bonus",     title = "XayaUI Bonus Features",  keys = { "dataPanels", "tooltips", "calculator", "notepad" }, marker = "calculator" },
    { m = "qol", short = "QoL",       title = "XayaUI QoL",             keys = { "cursorTrail", "cursorHighlight", "characterToolkit", "releaseGuard" }, marker = "cursorTrail" },
    { m = "devassist", short = "DevAssist", title = "XayaUI Dev Assist",      keys = { "idProbe", "chatProbe", "recCats" },               marker = "recCats" },
    { m = "core", short = "Rules",      title = "XayaUI Rules",           keys = { "barGroup", "auraAlias", "learnedAuraDur" },       marker = "barGroup" },
}
local MARK = "_qaP5"   -- (a key starting with "_" never goes into a profile string)

-- every value of the old copy is still there in the module's own settings (tables by contents). The module may have added what it
-- fills in at start-up (its defaults), so only the old values are compared, not what is new.
local function Kept(old, new, depth)
    depth = depth or 0
    if type(old) ~= "table" then return old == new or (old ~= old and new ~= new) end
    if type(new) ~= "table" then return false end
    if depth > 30 then return true end
    for k, v in pairs(old) do if k ~= MARK and not Kept(v, new[k], depth + 1) then return false end end
    return true
end
local function Count(t) return type(t) == "table" and #t or 0 end

QA.Register("settings-migration", { title = "Settings migration: each module's own saved settings, copied from CueRulesDB (part 1 of 2) (H16)", area = "Platform", qa = "H16", order = 272.95, prefill = true, steps = {
    { text = "Nothing to do: the check reads, for each module, where its settings are read from now and what the copy recorded.\n\n|cffffd100Expect:|r the record reads \"copied from CueRulesDB:\" and, for every module that is switched on, the version that made the copy and the day (\"now\" in the session it was made), or \"own, nothing to copy\" on a new install; none \"kept on CueRulesDB\". A module that is off reads \"off\".",
        check = function()
            if not (NS() and NS().SettingsStore) then return false, "XayaUI is older than 0.6.78 (no ns.SettingsStore)" end
            local lines, bad = {}, {}
            for _, d in ipairs(MODS) do
                local s = Store(d.m) or {}
                local line
                if s.state == "own" then
                    -- "copied from CueRulesDB" + the version that copied and the day (migratedBy "XayaUI_QoL 0.7.49", migratedAt "2026-11-08 12:00")
                    line = s.migratedFrom and (tostring(s.migratedBy):match("(%S+)$") .. " " .. tostring(s.migratedAt):sub(6, 10) .. (s.copiedNow and " now" or "")) or "own, nothing to copy"
                elseif s.state == "old" then
                    line = "kept on CueRulesDB"
                    bad[#bad + 1] = d.title .. ": kept on CueRulesDB (" .. tostring(s.mismatch and s.mismatch.diff or "?") .. ")"
                else
                    line = "off"
                end
                lines[#lines + 1] = d.short .. " " .. line
            end
            return #bad == 0, (#bad == 0 and "copied from CueRulesDB: " or (table.concat(bad, "; ") .. " | ")) .. table.concat(lines, ", ")
        end },
    { text = "Nothing to do: a few settings of each module are compared, its own saved settings against the old copy left in CueRulesDB.\n\n|cffffd100Expect:|r in the session the copy was made (the first login with this version), every old value is still there (a module may have added its defaults). In a later session a setting you changed since is meant to differ: the check then only lists them, with no verdict.",
        check = function()
            local same, diff, fresh, lines = 0, {}, false, {}
            for _, d in ipairs(MODS) do
                local s = Store(d.m) or {}
                if s.state == "own" and s.migratedFrom then
                    if s.copiedNow then fresh = true end
                    local V = View(d.m)
                    for _, k in ipairs(d.keys) do
                        local new, old = V[k], Old(d.m, k)
                        if old ~= nil or new ~= nil then
                            if Kept(old, new) then same = same + 1 else diff[#diff + 1] = d.m .. "." .. k end
                        end
                    end
                end
            end
            lines[#lines + 1] = ("%d compared settings keep every old value; changed or lost: %s"):format(same, #diff > 0 and table.concat(diff, ", ") or "none")
            if not fresh then return nil, "the copy was made in an earlier session (settings may have changed since): " .. lines[1] end
            return #diff == 0, lines[1]
        end },
    { text = "Nothing to do: XayaUI Rules' rules, groups and buff bars are counted in its own saved settings and in the old copy in CueRulesDB, and the backup made before the copy is looked for (Settings > Profiles > Backups, \"Rules before the settings move (<date>)\").\n\n|cffffd100Expect:|r the same numbers on both sides (in the session of the copy; later ones may differ by what you added or deleted since), and the backup listed with as many rules as the old copy.",
        check = function()
            local s = Store("core") or {}
            if s.state ~= "own" and s.state ~= "old" then return nil, "XayaUI Rules is off: nothing to count" end
            local C, ns = View("core"), NS()
            local n = { Count(C.rules), Count(C.folders), Count(C.bars) }
            local o = { Count(Old("core", "rules")), Count(Old("core", "folders")), Count(Old("core", "bars")) }
            local bk
            for _, b in ipairs(ns.Backups and ns.Backups() or {}) do if tostring(b.name):find("before the settings move", 1, true) then bk = b end end
            local bkN = bk and bk.data and Count(bk.data.rules) or nil
            local note = ("own: %d rules, %d groups, %d bars; CueRulesDB: %d rules, %d groups, %d bars; backup: %s"):format(n[1], n[2], n[3], o[1], o[2], o[3],
                bk and (tostring(bk.name) .. " with " .. tostring(bkN) .. " rules") or "none")
            if s.state == "old" then return false, "kept on CueRulesDB (" .. tostring(s.mismatch and s.mismatch.diff) .. ") | " .. note end
            if not s.migratedFrom then return nil, "a new install (nothing was copied, so no backup is made) | " .. note end
            if not s.copiedNow then return nil, "the copy was made in an earlier session (counts may have changed since) | " .. note end
            return (n[1] == o[1] and n[2] == o[2] and n[3] == o[3] and bkN == o[1]) and true or false, note
        end },
    { text = "Press |cffffd100Do it for me|r: a marker (the time now) is written into one table of each module's own saved settings (Blizzard Reskin's friend colours, the Chat Panel, the calculator, the cursor trail, Dev Assist's record categories, the buff bars' group). The markers change nothing you see; part 2 takes them out again.\n\n|cffffd100Expect:|r the check reads every marker back.",
        setup = function()
            local stamp = tostring(time and time() or 0)
            for _, d in ipairs(MODS) do
                local s = Store(d.m) or {}
                if s.state == "own" then
                    local V = View(d.m)
                    local t = V[d.marker]
                    if type(t) ~= "table" then t = {}; V[d.marker] = t end
                    t[MARK] = stamp
                end
            end
        end,
        check = function()
            local got, miss = {}, {}
            for _, d in ipairs(MODS) do
                local s = Store(d.m) or {}
                if s.state == "own" then
                    local t = View(d.m)[d.marker]
                    local v = type(t) == "table" and t[MARK] or nil
                    if v then got[#got + 1] = d.m .. "=" .. tostring(v) else miss[#miss + 1] = d.title end
                end
            end
            if #got == 0 and #miss == 0 then return nil, "press Do it for me first" end
            return #miss == 0, (#miss == 0 and "every marker is there" or ("missing: " .. table.concat(miss, ", "))) .. " | set: " .. table.concat(got, " ")
        end },
    { done = true, text = "Press |cffffd100Done|r here first (so this record is kept), type |cffffd100/reload|r, and run \"Settings migration: the markers after the /reload (part 2 of 2) (H16)\"." },
} })

QA.Register("settings-migration-reload", { title = "Settings migration: the markers after the /reload (part 2 of 2) (H16)", area = "Platform", qa = "H16", order = 272.96, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload.\n\n|cffffd100Expect:|r every marker part 1 wrote is still in each module's own saved settings, and no module copied again (the copy is made once).",
        check = function()
            local note = QA.SeenNote and QA.SeenNote("settings-migration", 4)
            local set = {}
            for m, v in tostring(note or ""):gmatch("(%w+)=(%d+)") do set[m] = v end
            if not next(set) then return nil, "part 1 has no record: run it to its end first (press Done before the /reload)" end
            local bad, again = {}, {}
            for _, d in ipairs(MODS) do
                if set[d.m] then
                    local t = View(d.m)[d.marker]
                    if not (type(t) == "table" and tostring(t[MARK]) == set[d.m]) then bad[#bad + 1] = d.title end
                    local s = Store(d.m) or {}
                    if s.copiedNow then again[#again + 1] = d.title end
                end
            end
            local ok = #bad == 0 and #again == 0
            return ok, ok and "every module kept its marker over the /reload and copied nothing again" or
                (("lost: %s; copied again: %s"):format(#bad > 0 and table.concat(bad, ", ") or "none", #again > 0 and table.concat(again, ", ") or "none"))
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to take the markers out again. Then press |cffffd100Done|r.",
        setup = function()
            for _, d in ipairs(MODS) do
                local s = Store(d.m) or {}
                if s.state == "own" then
                    local V = View(d.m)
                    local t = V[d.marker]
                    if type(t) == "table" then
                        t[MARK] = nil
                        if next(t) == nil and (d.marker == "friendColors" or d.marker == "recCats") then V[d.marker] = nil end
                    end
                end
            end
        end },
} })
