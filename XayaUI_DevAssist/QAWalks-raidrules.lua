-------------------------------------------------------------------------------
-- QAWalks-raidrules.lua (XayaUI_DevAssist 0.7.27): the in-game walkthrough for D8, Release Guard as a built-in entry under
-- Rules > Raid Rules (core 0.6.70, Options 0.6.68, QoL 0.7.42; QA B240-B246).
-- Xaya, 2026-11-07 (standing rule, relayed verbatim): "As a standing rule, make sure every feature or significant change to the
-- codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
-- prefill = true: where the addon can read the answer (the saved settings, its own load answer against what the game reports, its
-- frame) it offers its verdict on Accept; nothing is recorded without her click. What only a person can see (the sidebar row, the
-- right-click menu) is a question (noVerdict) and the addon writes what it read into the check line.
-- The first step remembers whether Release Guard was on; the last step puts it back. Does nothing without the framework or without
-- XayaUI_QoL (Release Guard's code). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
-- XayaUI_QoL's Release Guard and XayaUI_Options' Raid Rules entry are reached only through their services (Modules.lua)
local function Svc(name) local ns = NS(); return ns and ns.Service and ns.Service(name) end
local function Cfg() local sv = Svc("releaseGuard"); return sv and sv.Cfg and sv.Cfg() end
local function Scope() local sv = Svc("raidRules"); return sv and sv.Scope and sv.Scope() end
local function LoadsHere() local sv = Svc("releaseGuard"); return sv and sv.LoadsHere and sv.LoadsHere() end
local function Need() local c = Cfg(); if not c then error("XayaUI QoL is not loaded (Release Guard lives there)") end return c end
local function R(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b = pcall(fn, ...); if ok then return a, b end end
local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) == true end
local function Apply() local sv, ns = Svc("releaseGuard"), NS(); if sv and sv.Apply then pcall(sv.Apply) end; if ns and ns.MarkDirty then pcall(ns.MarkDirty) end end
-- the Load table in words (what the check line shows)
local function LoadText(L)
    if type(L) ~= "table" then return "not a Load table (" .. tostring(L) .. ")" end
    local t = {}
    if L.instance then t[#t + 1] = "in an instance: " .. tostring(L.instance) end
    if type(L.instanceTypes) == "table" then
        local k = {}
        for name, v in pairs(L.instanceTypes) do if v == true then k[#k + 1] = name end end
        table.sort(k)
        if #k > 0 then t[#t + 1] = "types: " .. table.concat(k, "+") end
    end
    if L.groupMin then t[#t + 1] = "people in group >= " .. tostring(L.groupMin) end
    if L.mode and L.mode ~= "all" then t[#t + 1] = "mode: " .. tostring(L.mode) end
    return (#t > 0) and table.concat(t, ", ") or "no conditions (everywhere)"
end
-- what the game says now (nil when it does not say)
local function Place()
    local inInst, kind = R(IsInInstance)
    local n = R(GetNumGroupMembers)
    if Secret(inInst) or Secret(kind) then inInst, kind = nil, nil end
    if Secret(n) or type(n) ~= "number" then n = nil end
    return inInst, kind, n
end

local wasOn
QA.Register("d8-raid-rules", { title = "Raid Rules: Release Guard as a built-in entry (D8)", qa = "B240-B246", order = 240, prefill = true, steps = {
    { text = "This walks through Release Guard's new home under |cffffd100Rules > Raid Rules|r. Press |cffffd100Do it for me|r: the addon notes whether Release Guard is on now (the last step puts that back).\n\n|cffffd100Expect:|r the addon reads Release Guard's saved settings.",
        setup = function() wasOn = Need().enabled == true end,
        check = function() local c = Need(); return true, "Release Guard is " .. (c.enabled and "on" or "off") .. "; noted" end },
    { text = "(B241) Where it works came over from the old \"Where\" setting.\n\n|cffffd100Expect:|r an old \"Raids only\" (the old default) became: in an instance, Raid, at least 20 people in the group. \"Raids and dungeons\" became Raid or Dungeon, any size; a saved \"Everywhere\" (removed in QoL 0.7.39) became the new default too. The old value is kept. (If you already changed its Load tab, the addon's answer here can read Fail for that reason.)",
        check = function()
            local c = Need()
            local L, old = c.load, c.loadOld
            local txt = "old: " .. tostring(old or "(none saved)") .. "; now: " .. LoadText(L)
            if type(L) ~= "table" then return false, txt end
            local types = L.instanceTypes or {}
            local ok
            if old == "group" then ok = L.instance == "yes" and types.raid == true and types.party == true and L.groupMin == nil
            else ok = L.instance == "yes" and types.raid == true and types.party == nil and L.groupMin == 20 end
            return ok, txt .. (ok and "" or " (if you changed its Load tab since, that is why)")
        end },
    { text = "(B240) Type |cffffd100/xui|r, open |cffffd100Rules|r, then the |cffffd100Smart Categories|r sub-tab.\n\n|cffffd100Expect:|r a |cffffd100RAID RULES|r group in the sidebar with |cffffd100Release Guard|r in it. Click it: two tabs, |cffffd100Settings|r (Enabled, the text, the flavour texts, the key) and |cffffd100Load|r (the same Load tab as a rule). The row has no eye or headphone. The QoL tab has no Release Guard row any more.",
        noVerdict = true,
        check = function()
            local ok = Svc("raidRules") ~= nil
            return ok, ok and "the Raid Rules entry is loaded (XayaUI Options)" or "XayaUI Options not opened yet: open /xui first, then Check again"
        end },
    { text = "(B242) Press |cffffd100Do it for me|r: Release Guard is switched on.\n\n|cffffd100Expect:|r its row is under |cffffd100Rules > Enabled|r (Loaded if you are in a raid with at least 20 people, else Not Loaded), no longer under Disabled.",
        setup = function() local c = Need(); c.enabled = true; Apply() end,
        check = function()
            local c = Need()
            local sc = Scope()
            return c.enabled == true and (sc == "loaded" or sc == "notloaded"), "on: " .. tostring(c.enabled) .. "; listed under: " .. tostring(sc)
        end },
    { text = "(B243) Join or stand in a raid instance with at least 20 people in your group (or in fewer, or outside: the addon checks either way). Then press Check.\n\n|cffffd100Expect:|r the addon's own answer matches the game: works only in a raid instance with 20 or more (with the default Load).",
        check = function()
            local c = Need()
            local inInst, kind, n = Place()
            if inInst == nil or n == nil then error("the game did not say where you are or how many are in your group") end
            local here = LoadsHere()
            local L = c.load or {}
            local note = ("instance: %s (%s), people: %d, works here: %s; Load: %s"):format(tostring(inInst), tostring(kind), n, tostring(here), LoadText(L))
            local types = L.instanceTypes or {}
            local default = L.instance == "yes" and types.raid == true and L.groupMin == 20 and (L.mode == nil or L.mode == "all")
            if not default then return here ~= nil, note .. " (Load changed from the default: compare by eye)" end
            local want = inInst == true and kind == "raid" and n >= 20
            return here == want, note
        end },
    { text = "(B244) Only where it works (step before said yes): die (fall damage works; you must be dead with the death window up).\n\n|cffffd100Expect:|r the black box over Release Spirit, as before. Hold your key (Shift by default): it steps aside.",
        check = function()
            local d = type(StaticPopup_FindVisible) == "function" and StaticPopup_FindVisible("DEATH")
            if not d then error("the death window is not up") end
            local box = rawget(_G, "XayaUIReleaseGuard")
            local shown = box and box.IsShown and box:IsShown()
            return shown == true, "death window up; cover " .. (shown and "shown" or "not shown")
        end },
    { text = "(B245) Right-click Release Guard's row in the sidebar.\n\n|cffffd100Expect:|r a menu with only |cffffd100Release Guard|r and |cffffd100Disable|r (no Rename, Duplicate, Export, Move or Delete). Dragging the row does nothing; Ctrl+click does not select it.",
        noVerdict = true,
        check = function() return true, "a question for you: the addon cannot see the menu" end },
    { text = "(B246) Press |cffffd100Do it for me|r: Release Guard is switched off.\n\n|cffffd100Expect:|r its row moves to |cffffd100Rules > Disabled|r; when you die nothing covers Release (nothing of it listens while off).",
        setup = function() local c = Need(); c.enabled = false; Apply() end,
        check = function()
            local c = Need()
            local sc = Scope()
            local box = rawget(_G, "XayaUIReleaseGuard")
            local hidden = not (box and box.IsShown and box:IsShown())
            return c.enabled == false and sc == "disabled" and hidden, "on: " .. tostring(c.enabled) .. "; listed under: " .. tostring(sc) .. "; cover hidden: " .. tostring(hidden)
        end },
    { text = "Press |cffffd100Do it for me|r: Release Guard is put back as it was before this walkthrough.",
        setup = function() local c = Need(); if wasOn ~= nil then c.enabled = wasOn end; Apply() end,
        check = function() local c = Need(); return wasOn == nil or c.enabled == wasOn, "on: " .. tostring(c.enabled) .. " (was " .. tostring(wasOn) .. ")" end },
} })

-- B247: the load condition "People in my group: at least N" on an ordinary rule (core 0.6.70 / Options 0.6.68; D8). Data capture plus
-- one verdict the addon can give safely: a rule that needs more people than are in your group must not be loaded.
QA.Register("d8-people-in-group", { title = "Load: People in my group, at least N (D8)", qa = "B247", order = 241, prefill = true, steps = {
    { text = "(B247) Open any rule's |cffffd100Load|r tab and set |cffffd100People in my group: at least|r to 3 (solo or in a 2-player group). Then press Check.\n\n|cffffd100Expect:|r the rule is under |cffffd100Not Loaded|r; the addon lists every rule with this setting, your group size and whether each is loaded.",
        check = function()
            local ns = NS()
            local _, _, n = Place()
            if n == nil then error("the game did not say how many are in your group") end
            local size = math.max(1, n)
            local okc, ctx = pcall(ns.ReadContext)
            local parts, bad, count = {}, 0, 0
            for _, r in ipairs(ns.rules or {}) do
                local need = type(r.load) == "table" and tonumber(r.load.groupMin)
                if need and need > 1 then
                    count = count + 1
                    local loaded = okc and ns.IsLoaded(r, ctx) or false
                    if size < need and loaded then bad = bad + 1 end
                    if #parts < 6 then parts[#parts + 1] = ("%s (>= %d): %s"):format(tostring(r.name or "?"), need, loaded and "loaded" or "not loaded") end
                end
            end
            if count == 0 then error("no rule has People in my group set yet") end
            return bad == 0, ("group size %d; %s"):format(size, table.concat(parts, "; ")) .. (bad > 0 and (" -- %d loaded with too few people"):format(bad) or "")
        end },
    { text = "Now be in a group with at least as many people as you set (or set the number to 1-2 less than your group). Press Check.\n\n|cffffd100Expect:|r the rule moves to |cffffd100Loaded|r (if its other load conditions match). Set it back to 0 (any) when done.",
        noVerdict = true,
        check = function()
            local _, _, n = Place()
            return true, "group size now: " .. tostring(n and math.max(1, n) or "unknown")
        end },
} })
