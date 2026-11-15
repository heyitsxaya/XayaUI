-- TalentDump.lua - /xui debug talents (Core.lua, through XayaUI Rules' "rules" service, RuleDefaults.lua) and the small reader of the saved
-- talent scan.
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58, her words: "Move all four (Recommended)"; V34) The talent scan itself (scan every class's
-- talents) is XayaUI Options' (XayaUI_Options/TalentDump.lua), read only when the settings window's code loads. The scan it saves stays
-- this addon's saved variable XayaUITalentDB (## SavedVariables in XayaUI_Rules.toc), so no saved scan is lost.
-- (bundle 1 round 8, REQUEST-LOG A23 SD-67, her answer on /xui debug talents status and the name search: "Read-only answers anytime
-- (Recommended)") The reader stays here, with the saved data: "/xui debug talents status" and "/xui debug talents <name>" answer at once,
-- in or out of combat, whether or not XayaUI Options has loaded or is installed, and they never load it (out of combat, status no longer
-- loads all of XayaUI Options to print one line). They only read XayaUITalentDB: exempt from the combat lock (V26: read-only /xui debug
-- commands; Modules.lua COMBAT_LOCK_EXEMPT.talentsRead). Only the scan ("/xui debug talents" alone) changes state, so only the scan is
-- locked in combat (V26: "Lock it") and only the scan needs XayaUI Options: in combat one line, and it runs when combat ends; out of
-- combat it loads the settings window's code without opening the window (core's ns.LoadOptions) and runs the scan there.
-- V24 / V25 cost: nothing until typed; status walks the saved scan once (13 classes), the name search at most every saved talent entry once.
local _, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)

local MAX_HITS = 25   -- the name search prints at most this many lines

-- The saved scan is read as data: a field of the wrong type (a damaged or hand-edited saved file) prints as "?" or is left out, never a
-- Lua error. txt: a string or number as it is, anything else nil.
local function txt(v) local t = type(v); if t == "string" or t == "number" then return v end end

-- the saved scan (XayaUI Options' rule editor reads it through here too)
function ns.TalentDB() return XayaUITalentDB end

-- one line: when the saved scan was made and how much it holds
function ns.TalentStatus()
    local db = XayaUITalentDB
    if not (type(db) == "table" and type(db.classes) == "table") then return "No talent scan saved yet." end
    local nC, nN = 0, 0
    for _, c in pairs(db.classes) do
        nC = nC + 1
        if type(c) == "table" and type(c.nodes) == "table" then for _ in pairs(c.nodes) do nN = nN + 1 end end
    end
    return ("Last talent scan %s (build %s): %d classes, %d nodes."):format(txt(db.built) or "?", txt(db.build) or "?", nC, nN)
end

-- prints every saved talent whose name holds `text` (plain, any case), at most MAX_HITS lines
local function FindTalents(text)
    local db, hits = XayaUITalentDB, 0
    if not (type(db) == "table" and type(db.classes) == "table") then ns.Print("No talent scan saved yet - run /xui debug talents first."); return end
    local want = text:lower()
    for _, c in pairs(db.classes) do
        for _, n in pairs(type(c) == "table" and type(c.nodes) == "table" and c.nodes or {}) do
            for _, e in ipairs(type(n) == "table" and type(n.e) == "table" and n.e or {}) do
                if hits < MAX_HITS and type(e) == "table" and type(e.name) == "string" and e.name:lower():find(want, 1, true) then
                    hits = hits + 1
                    local sp = {}
                    local names = type(c.specs) == "table" and c.specs or {}
                    for sid in pairs(type(n.specs) == "table" and n.specs or {}) do sp[#sp + 1] = tostring(txt(names[sid]) or txt(sid) or "?") end
                    table.sort(sp)
                    local cd = type(e.cd) == "number" and e.cd
                    ns.Print(("%s [%s]: %s (spell %s)%s%s - %s"):format(txt(c.name) or "?", txt(n.scope) or "?", e.name, txt(e.spell) or "?",
                        e.passive and " passive" or "", cd and (" cd " .. cd .. "s") or "", table.concat(sp, "/")))
                end
            end
        end
    end
    if hits == 0 then ns.Print("no talent matching '" .. text .. "' in the last scan.") end
end

-- With XayaUI Options switched off or not installed, the scan ("/xui debug talents" alone) says so in one line naming the command
-- (core's ns.LoadOptions says it only once per session). Read from the game's addon list (C_AddOns.GetAddOnInfo's reason,
-- docs/reference/api/namespaces.md:148); it loads nothing, so it answers in combat too.
local function OptionsUnavailableLine()
    local A = C_AddOns
    if not (A and A.GetAddOnInfo) then return nil end
    local ok, name, _, _, _, reason = pcall(A.GetAddOnInfo, ns.OPTIONS_ADDON or "XayaUI_Options")
    if not ok then return nil end
    if reason == "MISSING" or not name then
        return "/xui debug talents is part of the settings window (XayaUI Options), which is not installed: the XayaUI_Options folder belongs next to XayaUI in Interface\\AddOns."
    elseif reason == "DISABLED" then
        return "/xui debug talents is part of the settings window (XayaUI Options), which is switched off. Turn it on in the game's AddOns list, then /reload."
    end
    return nil
end

local SCAN_LOCK = "the talent scan can't run during combat. It will run when combat ends."
local function OptionsScan() local O = ns.OptionsApi; return O and O.TalentScan end
local function Scan()
    if not OptionsScan() then
        local off = OptionsUnavailableLine()
        if off then ns.Print(off); return end
        if not (ns.LoadOptions and ns.LoadOptions()) then return end   -- (ns.LoadOptions says itself why it could not load)
        if not OptionsScan() then return end
    end
    OptionsScan()()
end

function ns.TalentCommand(arg)
    arg = tostring(arg or ""):match("^%s*(.-)%s*$")
    if arg == "" then
        -- XayaUI Options switched off or missing: said at once, in or out of combat (nothing would run after combat either)
        local off = not OptionsScan() and OptionsUnavailableLine()
        if off then ns.Print(off); return end
        -- (V26: "Lock it") the scan changes the game's talent view and the saved scan: in combat one line, and it runs when combat ends
        if ns.CombatLock then ns.CombatLock("talents", Scan, SCAN_LOCK) else Scan() end
        return
    end
    -- (V26: read-only, exempt; SD-67) the key is in core's exempt list, so ns.CombatLock runs the read at once, in combat too
    local function Read() if arg:lower() == "status" then ns.Print(ns.TalentStatus()) else FindTalents(arg) end end
    if ns.CombatLock then ns.CombatLock("talentsRead", Read) else Read() end
end
