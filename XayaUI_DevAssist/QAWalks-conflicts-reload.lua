-------------------------------------------------------------------------------
-- QAWalks-conflicts-reload.lua (XayaUI_DevAssist 0.7.60): in-game QA walkthroughs for XayaUI 0.6.79 (QA step I2).
--   PS-56, #469 (Xaya, 2026-11-08): "Make sure all addons that have conflicts with each other (EUI with the chat reskin, elvui with the
--   chat reskin, etc) get appropriately flagged."
--   PS-57, #480 (Xaya, 2026-11-08): "Enabling/disabling reskins and modules should require a reload to take effect to account for
--   memory/cpu changes as well"
-- "conflicts" (pre-fill, V22): what XayaUI found at login (data capture: the loaded overlapping addons and the login line), checked
-- against a fresh read of the AddOns list; then each flagged part's settings page has its line.
-- "switch-reload" in three parts around two /reloads: a reskin switch (Blizzard Reskin > Chat Bubbles) and a module switch
-- (QoL > Nameplates) are clicked the way their tick boxes are (the switch's own set); each asks for a reload and changes nothing
-- before it; after the /reload the change is in effect; part 2 flips both back, part 3 finds them as they were. No saved key of its
-- own: each part reads what the one before recorded in its saved result (QA.SeenNote); a /reload is told apart by a flag that only
-- lives until the reload. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local function NS() return rawget(_G, "XayaUI_NS") end

-- conflicts -----------------------------------------------------------------------------------------------------------------------
-- the AddOns list read again, the same way the Platform reads it (C_AddOns.IsAddOnLoaded, docs/reference/api/namespaces.md:162)
local function LoadedNow(name)
    local A = rawget(_G, "C_AddOns")
    if not (A and A.IsAddOnLoaded) then return false end
    local ok, a, b = pcall(A.IsAddOnLoaded, name)
    if not ok then return false end
    if b ~= nil then return b and true or false end
    return a and true or false
end
-- every (part, addon) pair the registry names whose addon is loaded now, sorted: what the login detection should have found
local function Expected()
    local ns, out = NS(), {}
    for _, c in ipairs(ns and ns.Conflicts and ns.Conflicts() or {}) do
        for _, a in ipairs(c.addons) do if LoadedNow(a) then out[#out + 1] = c.part .. ":" .. a end end
    end
    table.sort(out)
    return out
end
local function Found()
    local ns, out = NS(), {}
    for _, c in ipairs(ns and ns.Conflicts and ns.Conflicts() or {}) do
        for _, e in ipairs(ns.ConflictsFor(c.part) or {}) do out[#out + 1] = e.part .. ":" .. e.addon end
    end
    table.sort(out)
    local dedup, last = {}, nil
    for _, v in ipairs(out) do if v ~= last then dedup[#dedup + 1] = v end; last = v end
    return dedup
end
local function FlaggedParts()
    local seen, out = {}, {}
    for _, pa in ipairs(Found()) do local p = pa:match("^(.-):"); if p and not seen[p] then seen[p] = true; out[#out + 1] = p end end
    return out
end
-- the settings window's own options table as last drawn (ns.OptionsApi.LastTree, as the E2e walkthrough reads it); the window is opened
-- through the Platform (ns.OpenSettingsPage) when it has not drawn one yet
local function Tree(tab, key)
    local ns = NS()
    if not ns then return nil end
    local last = ns.OptionsApi and ns.OptionsApi.LastTree and ns.OptionsApi.LastTree()
    if not last and ns.OpenSettingsPage then ns.OpenSettingsPage(tab or "reskin", key or "reskinOverview"); last = ns.OptionsApi and ns.OptionsApi.LastTree and ns.OptionsApi.LastTree() end
    return last
end
local function PageOf(tree, key)
    for _, tab in ipairs({ "reskin", "qol", "bonus", "chat" }) do
        local t = tree and tree.args and tree.args[tab]
        local g = t and t.args and t.args[key]
        if g then return g, tab end
    end
end
QA.Register("conflicts", { title = "Overlaps with other addons: the login line and each flagged page (I2, PS-56)", qa = "I2", order = 511, prefill = true, steps = {
    { text = "Log in (or /reload) with the addons you normally use, then open this walkthrough.\n\n|cffffd100Expect:|r if an addon that changes the same thing as a XayaUI part is loaded (for example ElvUI or EllesmereUI's chat), one chat line at login: \"XayaUI: overlaps with other loaded addons: ...\", naming each such addon and the XayaUI parts that are on. Nothing of XayaUI was switched off for it. The check reads the AddOns list again and compares.",
        check = function()
            local ns = NS()
            if not (ns and ns.Conflicts and ns.ConflictsFor) then return false, "this XayaUI has no overlap flags (XayaUI 0.6.79 or later)" end
            local want, got = Expected(), Found()
            local line = ns.ConflictLoginLine and ns.ConflictLoginLine() or nil
            local same = table.concat(want, ",") == table.concat(got, ",")
            return same, ("found at login: %s; read now: %s; login line: %s"):format(#got > 0 and table.concat(got, ", ") or "none",
                #want > 0 and table.concat(want, ", ") or "none", line or "(none: no overlapping addon loaded, or the overlapped parts are off)")
        end },
    { text = "Press |cffffd100Do it for me|r: the settings window opens on the first flagged part's page.\n\n|cffffd100Expect:|r an orange line at the top of that page: \"Overlaps with <addon> (loaded): both change <what>.\" Every flagged part's page has its line (the check reads them all). Nothing is flagged when no overlapping addon is loaded: then Pass.",
        setup = function()
            local ns, parts = NS(), FlaggedParts()
            local tree = Tree()
            local _, tab = PageOf(tree, parts[1])
            if parts[1] and ns.OpenSettingsPage then ns.OpenSettingsPage(tab or "qol", parts[1]) end
        end,
        check = function()
            local parts = FlaggedParts()
            if #parts == 0 then return true, "no part is flagged (no overlapping addon loaded)" end
            local tree = Tree()
            if not tree then return false, "the settings window could not load" end
            local ok, bad = {}, {}
            for _, p in ipairs(parts) do
                local g = PageOf(tree, p)
                local f = g and g.args and g.args.xuiConflict
                local text = f and f.name
                if type(text) == "string" and text:find("Overlaps with", 1, true) then ok[#ok + 1] = p else bad[#bad + 1] = p end
            end
            return #bad == 0, ("pages with their line: %s%s"):format(#ok > 0 and table.concat(ok, ", ") or "none", #bad > 0 and ("; MISSING on: " .. table.concat(bad, ", ")) or "")
        end },
    { done = true, text = "Press |cffffd100Done|r." },
} })

-- switch-reload -------------------------------------------------------------------------------------------------------------------
local pending   -- set when a part flips a switch; gone after a /reload (Lua state is rebuilt)
QA.SwitchReloadPending = function() return pending end   -- (tests)
local function Bubbles() local ns = NS(); local sv = ns and ns.Service and ns.Service("blizzardSkins"); return sv end
local function NP() local ns = NS(); return ns and ns.Service and ns.Service("nameplates") end
local function BubblesLive() local sv = Bubbles(); return sv and sv.Live().bubbles and true or false end
local function NPLive() local np = NP(); return np and np.TargetColor and np.TargetColor.Listening() and true or false end
local function Switch(tab, key)
    local tree = Tree(tab, key)
    local g = tree and tree.args and tree.args[tab] and tree.args[tab].args and tree.args[tab].args[key]
    return g and g.xuiSwitch
end
local function Asked()
    if type(StaticPopup_Visible) == "function" then local ok, v = pcall(StaticPopup_Visible, "XAYAUI_RESKIN_RELOAD"); if ok and v then return true end end
    return type(StaticPopupDialogs) == "table" and StaticPopupDialogs.XAYAUI_RESKIN_RELOAD ~= nil
end
local function OnOff(v) return v and "ON" or "OFF" end
-- flip one switch through its tick box's own set; record what it was, what is saved now, what is drawn
local function Flip(tab, key, live)
    local ns = NS()
    if ns.OpenSettingsPage then ns.OpenSettingsPage(tab, key) end
    local sw = Switch(tab, key)
    if not sw then error("the switch was not found: is its addon loaded?") end
    local was = sw.get({}) and true or false
    pending = pending or {}
    pending[key] = { was = was, drawn = live() }
    sw.set({}, not was)   -- (what a click on the tick box does: saves the choice and asks "reload now?")
end
local function FlipCheck(tab, key, live, label)
    local p = pending and pending[key]
    if not p then return false, "the switch was not changed in this session: press Do it for me" end
    local sw = Switch(tab, key)
    local now = sw and sw.get({}) and true or false
    local drawn = live()
    local ok = now ~= p.was and drawn == p.drawn and Asked()
    return ok, ("%s saved now %s (was %s); drawn before the reload: %s (was %s); the reload question: %s"):format(label, OnOff(now), OnOff(p.was),
        OnOff(drawn), OnOff(p.drawn), Asked() and "asked" or "NOT asked")
end
local function AfterReload(prevId, label)
    if pending then return nil, "not reloaded yet: type /reload (or press Reload in the question), then come back and Check again" end
    local nb = QA.SeenNote(prevId, 1); local nn = QA.SeenNote(prevId, 2)
    local wb = nb and nb:match("saved now (%u+)"); local wn = nn and nn:match("saved now (%u+)")
    if not (wb and wn) then return nil, ("%s has no record of the switches: run it to its end first"):format(label) end
    local ns = NS()
    local tabOn = ns.ReskinTabOn and ns.ReskinTabOn()
    local wantB = (wb == "ON") and tabOn and true or false
    local gotB, gotN = BubblesLive(), NPLive()
    local ok = gotB == wantB and gotN == (wn == "ON")
    return ok, ("Chat Bubbles drawn: %s (%s set %s%s); Nameplates colour listening: %s (%s set %s)"):format(OnOff(gotB), label, wb,
        tabOn and "" or ", Blizzard Reskin off", OnOff(gotN), label, wn)
end
QA.Register("switch-reload", { title = "Reskin and module switches take effect on reload (part 1 of 3) (I2, PS-57)", qa = "I2", order = 512, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on Blizzard Reskin > |cffffd100Chat Bubbles|r and its tick box is switched to the other setting, the way a click does.\n\n|cffffd100Expect:|r a question \"Chat Bubbles: this change takes effect after a reload. Reload now?\" with Reload / Later. Chat bubbles look as before. Press |cffffd100Later|r.",
        setup = function() Flip("reskin", "rskbubbles", BubblesLive) end,
        check = function() return FlipCheck("reskin", "rskbubbles", BubblesLive, "Chat Bubbles") end },
    { text = "Press |cffffd100Do it for me|r: QoL > |cffffd100Nameplates|r (the whole XayaUI Nameplates module's switch) is switched to the other setting.\n\n|cffffd100Expect:|r the question \"Nameplates: this change takes effect after a reload. Reload now?\". Your target's nameplate colour is as before. Press |cffffd100Later|r.",
        setup = function() Flip("qol", "nameplates", NPLive) end,
        check = function() return FlipCheck("qol", "nameplates", NPLive, "Nameplates") end },
    { done = true, text = "Press |cffffd100Done|r here first (so this part's record is kept), then type |cffffd100/reload|r. After the loading screen, open |cffffd100/xui dev qa|r and run \"Reskin and module switches ... (part 2 of 3, after the /reload)\"." },
} })
QA.Register("switch-reload-after", { title = "Reskin and module switches take effect on reload (part 2 of 3, after the /reload) (I2)", qa = "I2", order = 512.1, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload. Target something with a nameplate, then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r both changes are in effect now: chat bubbles in the XayaUI look if part 1 switched Chat Bubbles on (Blizzard's if off); the target's nameplate coloured if Nameplates is on (Blizzard's if off).",
        check = function() return AfterReload("switch-reload", "part 1") end },
    { text = "Press |cffffd100Do it for me|r: both switches are flipped back (Chat Bubbles, then Nameplates).\n\n|cffffd100Expect:|r the reload question again; nothing changes before the reload. Press |cffffd100Later|r.",
        setup = function() Flip("reskin", "rskbubbles", BubblesLive); Flip("qol", "nameplates", NPLive) end,
        check = function()
            local okB, nb = FlipCheck("reskin", "rskbubbles", BubblesLive, "Chat Bubbles")
            local okN, nn = FlipCheck("qol", "nameplates", NPLive, "Nameplates")
            return okB and okN, nb .. "; " .. nn
        end },
    { done = true, text = "Press |cffffd100Done|r here first, then type |cffffd100/reload|r and run \"Reskin and module switches ... (part 3 of 3, back as they were)\"." },
} })
QA.Register("switch-reload-back", { title = "Reskin and module switches take effect on reload (part 3 of 3, back as they were) (I2)", qa = "I2", order = 512.2, prefill = true, steps = {
    { text = "Run this after part 2 and its /reload. Target something with a nameplate, then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r Chat Bubbles and Nameplates are as they were before part 1, and drawn that way.",
        check = function()
            if pending then return nil, "not reloaded yet: type /reload, then come back and Check again" end
            local n1, n2 = QA.SeenNote("switch-reload", 1), QA.SeenNote("switch-reload", 2)
            local wb = n1 and n1:match("%(was (%u+)%)"); local wn = n2 and n2:match("%(was (%u+)%)")
            if not (wb and wn) then return nil, "part 1 has no record of the switches: run it to its end first" end
            local ns = NS()
            local tabOn = ns.ReskinTabOn and ns.ReskinTabOn()
            local gotB, gotN = BubblesLive(), NPLive()
            local ok = gotB == ((wb == "ON") and tabOn and true or false) and gotN == (wn == "ON")
            return ok, ("Chat Bubbles drawn: %s (before part 1: %s); Nameplates colour listening: %s (before part 1: %s)"):format(OnOff(gotB), wb, OnOff(gotN), wn)
        end },
} })
