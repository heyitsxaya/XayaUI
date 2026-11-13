-------------------------------------------------------------------------------
-- XayaUI Debug: /xuiengine, the combat aura engine's status: what it draws, what it does not and why, and every difference it cannot
-- avoid. Moved from XayaUI_Rules/Combat/AuraDisplay.lua in bundle 1 round 7 (REQUEST-LOG A23 SD-58, her answer on the debug tools: "1 but
-- nothing loads unless "Debugging" is enabled"; Tools.lua says how this addon loads). The engine keeps a small read-only data hook,
-- ns.AuraDisplay.StatusData(), and the /xuiengine slash command itself, which runs EngineStatus (below, offered through this addon's
-- "rulesdebug" service, Modules.lua ns.Provide / ns.Service) while this addon is loaded and otherwise answers with core's one plain line. With XayaUI Rules switched off this file defines nothing (no /xuiengine).
-- (V26, SD-16; Xaya 2026-11-10 on /xuiengine full and /xuiengine refresh: "Remove entirely"; "/xui shouldn't have anything that allows
-- configuration of rules through the console") /xuiengine only shows the status, which reads and changes nothing; it works in combat
-- (read-only debugging is exempt from the combat lock). A word XayaUI Dev Assist registers (ns.RegisterSubcommand("xuiengine", ...),
-- qa-installer-branch) is passed on to it, as before; (SD-47) none of those changes the engine. V24 / V25 cost: nothing until typed.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI) and XayaUI Rules
local D = ns.AuraDisplay
if not (D and D.StatusData and D.DB) then return end   -- (XayaUI Rules is switched off: no combat engine)
local function Say(...) if ns.Print then ns.Print(...) end end

-- (D.Status: the same name the engine used before round 7, kept so the engine's readers and tests reach the text the same way)
function D.Status()
    local s = D.StatusData()
    if not s then return end
    if s.off then
        Say("the combat engine is off because every rule is off (/xui disable). /xui enable, or a /reload, turns rules and the engine back on.")
        return
    end
    local nG, nGRules = 0, 0
    for _, g in ipairs(s.groups) do
        nG, nGRules = nG + 1, nGRules + g.n
        Say(string.format("%s: %s (%d buff rules)%s", g.name, g.ok and "ENGINE DRAWN" or "NOT drawn by engine (XayaUI draws it)",
            g.n, g.err and (" - " .. g.err) or ""))
        if g.ok then
            if g.mixed and not g.manual then Say("   (icons in this group have different sizes; with a game sort the engine draws them all at the first one's size; Manual sort keeps each size)") end
            if g.sort then Say("   (sort: " .. g.sort .. (g.reversed and ", reversed" or "") .. ")") end
            for _, d in ipairs(g.drops) do Say("   " .. d.name .. ": " .. d.text) end
        end
    end
    for _, x in ipairs(s.singles) do
        if x.text then Say("   " .. x.name .. " (on its own): " .. x.text) end
    end
    for _, x in ipairs(s.extras) do
        if x.text then Say("   " .. x.name .. " (extra display of " .. x.parent .. "): " .. x.text) end
    end
    local nSOk, nX = #s.singles, #s.extras
    Say(string.format("Engine draws: %d group%s (%d rules) and %d rule%s on their own%s.", nG, nG == 1 and "" or "s", nGRules, nSOk, nSOk == 1 and "" or "s",
        nX > 0 and string.format(", plus %d separate time / stack display%s of those rules", nX, nX == 1 and "" or "s") or ""))
    if #s.left > 0 then
        -- grouped by reason, so a long list stays readable; every display XayaUI keeps is counted
        local byWhy, order = {}, {}
        for _, e in ipairs(s.left) do
            local l = byWhy[e.why]
            if not l then l = {}; byWhy[e.why] = l; order[#order + 1] = e.why end
            l[#l + 1] = e.name
        end
        Say(string.format("XayaUI keeps %d aura display%s:", #s.left, #s.left == 1 and "" or "s"))
        for _, why in ipairs(order) do
            local l = byWhy[why]
            local shown = {}
            for i = 1, math.min(6, #l) do shown[i] = l[i] end
            Say(string.format("   %d - %s: %s%s", #l, why, table.concat(shown, ", "), #l > 6 and (", and " .. (#l - 6) .. " more") or ""))
        end
    else
        Say("XayaUI keeps no aura displays: every one is drawn by the engine.")
    end
    Say("combat engine: on (it always runs while any rule is on).")
    if s.lastError then Say("last engine error: " .. s.lastError) end
end

local function EngineStatus(msg)
    local cmd, rest = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if not D.DB() then Say("saved data not loaded yet") return end
    if cmd ~= "" and ns.RunSubcommand and ns.RunSubcommand("xuiengine", cmd, rest) then
        -- (a developer word Dev Assist registered; none changes the engine, SD-47)
    else
        D.Status()
        -- (no "|r" in chat text: WoW reads it as a colour code)
        Say("/xuiengine shows what the combat engine draws; it changes nothing." .. (ns.SubcommandList and ns.SubcommandList("xuiengine", "/xuiengine ") or "")
            .. "  The engine draws aura displays through the game's own aura frames, so time and stacks show in combat.")
    end
end
local svc = ns.Service("rulesdebug") or {}
svc.EngineStatus = EngineStatus
ns.Provide("rulesdebug", svc)
