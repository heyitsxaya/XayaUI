-------------------------------------------------------------------------------
-- ReleaseGuard.lua : Release Guard (XayaUI QoL 0.7.31; D8, QoL 0.7.42: shown under Rules > Raid Rules). A black box over the death window's Release Spirit button, so a misclick
-- does not release you in a raid. Off by default; while off nothing is created, registered or hooked (V14).
-- Xaya (REQUEST-LOG #10, #39, #75, #76; her words): "autopopulating the rule calculator with things like "DO NOT RELEASE" button cover in
-- raid"; "both: requires a modifier key to allow click-through"; "black box over the "release" button that says "NO RELEASE"
-- (customizable); also allow cycling through flavor texts (configurable) "BAD MONKEY," "death comes for us all," "NOPE," "Disagree,"
-- "WTB Rez""; hide as a ghost; load "configurable, by default raid only"; the modifier: "Choice in settings" (Shift / Ctrl / Alt, Shift to
-- start); the flavour text changes "Each death" (her list in order).
-- Saved settings: CueRulesDB.releaseGuard. NOT RUN IN GAME when written (2026-11-06): QA E1z82.
--
-- The game's side (Blizzard's 12.1.5 source mirror, 12.1.5.70688): the death window is the StaticPopup "DEATH"
-- (Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua:183): button1 = DEATH_RELEASE, whose OnButton1 calls RepopMe() (:229-236). A shown
-- popup is found with StaticPopup_FindVisible(which) (Blizzard_StaticPopup/StaticPopup.lua:148) and its first button with
-- dialog:GetButton1() (Blizzard_StaticPopup_Game/GameDialog.lua:525). Shown through StaticPopup_Show(which, ...) (StaticPopup.lua:300):
-- a post-hook (hooksecurefunc, placed only once the guard is on; it returns at once while off) finds the DEATH dialog when it shows.
-- Documented calls (docs/reference/api): IsInInstance() -> isInInstance: bool, instanceType: cstring (globals.md:353); UnitIsGhost(unit)
-- -> result: bool · SecretArguments=AllowedWhenUntainted (globals.md:638); IsShiftKeyDown / IsControlKeyDown / IsAltKeyDown; events
-- PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST (events.md:1169, 1159, 1229; SynchronousEvent · DeathInfo), MODIFIER_STATE_CHANGED (only
-- registered while the box shows).
-- How the box works: a plain frame of XayaUI's own (not secure, nothing protected is called, Release is never pressed for her), on the
-- DIALOG strata above the popup, over button1, taking the mouse so a click there lands on the box. While the chosen key is held the box
-- hides, so the click reaches Release; let go and it is back. It hides when the popup closes, when she is alive or a ghost.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns

local FLAVORS = { "BAD MONKEY", "death comes for us all", "NOPE", "Disagree", "WTB Rez" }
ns.RELEASEGUARD_DEFAULTS = { enabled = false, text = "NO RELEASE", flavorOn = true, flavors = table.concat(FLAVORS, "\n"), modifier = "SHIFT",
    index = 0 }
local MODS = { SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt" }
-- D8 (QoL 0.7.42; Xaya: "Rule drives the cover"; load "in instance - raid party size => 20"): where it works is a rule-style Load table
-- (c.load, edited with the rule Load tab under Rules > Raid Rules > Release Guard; core ns.LoadAllows decides). Her default: in an
-- instance, instance type Raid, people in my group at least 20.
local function DefaultLoad() return { instance = "yes", instanceTypes = { raid = true }, groupMin = 20 } end
ns.ReleaseGuard_DefaultLoad = DefaultLoad
-- the old "Where" setting (QoL 0.7.31-0.7.41: c.load = "raid" | "group" | "all") becomes a Load table once, the old value kept in
-- c.loadOld. Conservative reading (she was not asked: "stop asking me questions", 2026-11-07): a choice she changed keeps exactly what
-- it did ("group" = in an instance, Raid or Dungeon, any size). "raid" was the default, so a saved "raid" cannot be told apart from
-- never touched: it takes her new default. "all" (Everywhere) already became "raid" in QoL 0.7.39 (UI-58, Xaya: "There also should
-- not be an everywhere button"): the new default too.
local OLD_LOADS = {
    raid = DefaultLoad,
    group = function() return { instance = "yes", instanceTypes = { raid = true, party = true } } end,
    all = DefaultLoad,
}
-- the Load table in words (/xui releaseguard and the last-death note)
local function LoadText(L)
    if type(L) ~= "table" then return tostring(L) end
    local t = {}
    if L.mode == "never" then return "never" end
    if L.instance == "yes" then t[#t + 1] = "in an instance" elseif L.instance == "no" then t[#t + 1] = "not in an instance" end
    if type(L.instanceTypes) == "table" then
        local k = {}
        for name, v in pairs(L.instanceTypes) do if v == true then k[#k + 1] = name end end
        table.sort(k)
        if #k > 0 then t[#t + 1] = table.concat(k, "/") end
    end
    if tonumber(L.groupMin) then t[#t + 1] = "at least " .. tostring(L.groupMin) .. " in the group" end
    return (#t > 0) and table.concat(t, ", ") or "its other Load tab settings"
end

local function Cfg()
    if not CueRulesDB then return nil end
    local c = CueRulesDB.releaseGuard
    if type(c) ~= "table" then c = {}; CueRulesDB.releaseGuard = c end
    for k, v in pairs(ns.RELEASEGUARD_DEFAULTS) do if c[k] == nil then c[k] = v end end
    c.enabled, c.flavorOn = c.enabled == true, c.flavorOn ~= false
    if not MODS[c.modifier] then c.modifier = "SHIFT" end
    if type(c.load) ~= "table" then
        local old = c.load
        if type(old) == "string" and c.loadOld == nil then c.loadOld = old end
        c.load = (OLD_LOADS[old] or DefaultLoad)()
    end
    if c.talentMode ~= "all" and c.talentMode ~= "any" then c.talentMode = "none" end
    if type(c.talents) ~= "table" then c.talents = {} end
    if type(c.text) ~= "string" then c.text = "NO RELEASE" end
    if type(c.flavors) ~= "string" then c.flavors = ns.RELEASEGUARD_DEFAULTS.flavors end
    c.index = math.floor(tonumber(c.index) or 0)
    return c
end
ns.ReleaseGuard_Cfg = Cfg

-- her flavour texts, one per line of the setting (empty lines left out)
local function Flavors(c)
    local out = {}
    for line in (tostring(c.flavors or "") .. "\n"):gmatch("(.-)\r?\n") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then out[#out + 1] = line end
    end
    return out
end
ns.ReleaseGuard_Flavors = Flavors

local function R(fn, ...) if type(fn) ~= "function" then return nil end; local ok, a, b = pcall(fn, ...); if ok then return a, b end end
local function IsSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) == true end
-- where it loads: the rule Load tab's answer for its Load table (core ns.LoadAllows; read only when the death window shows, nothing
-- polled). Unknown = not loaded (never a guess).
local function LoadsHere(c)
    return type(ns.LoadAllows) == "function" and ns.LoadAllows(c) == true
end
ns.ReleaseGuard_LoadsHere = function() local c = Cfg(); return c and LoadsHere(c) or false end
local function Ghost() local g = R(UnitIsGhost, "player"); return g == true end
local function ModDown(c)
    local f = (c.modifier == "CTRL" and IsControlKeyDown) or (c.modifier == "ALT" and IsAltKeyDown) or IsShiftKeyDown
    local v = R(f)
    return v == true
end

local box, ev, hooked
local STRATA = "FULLSCREEN_DIALOG"
local state = { dialog = nil, death = 0, why = "no death seen yet" }
ns.ReleaseGuardState = state   -- (tests)

local function Hide()
    if box then box:Hide() end
    state.dialog = nil
    if ev then ev:UnregisterEvent("MODIFIER_STATE_CHANGED") end
end
local function Theme(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, col = pcall(T.Col, class, prop, fb); if ok and type(col) == "table" then return col end end
    return fb
end
local function Build()
    if box then return box end
    box = CreateFrame("Button", "XayaUIReleaseGuard", UIParent)
    -- (QoL 0.7.39; REQUEST-LOG UI-57, Insivius: "Release guard doesn't seem to work outside of instances") one strata above the game's
    -- dialogs: StaticPopup_OnShow raises the death window to the top of the DIALOG strata (Blizzard_StaticPopup/StaticPopup.lua:582,
    -- dialog:Raise()), and a frame level set beside it does not survive every raise, so in DIALOG the box could sit behind the window.
    -- INFERENCE (not seen in the game): the cause is that layering; `/xui releaseguard` reports it after a death.
    box:SetFrameStrata(STRATA)
    box:EnableMouse(true)
    if box.RegisterForClicks then box:RegisterForClicks("AnyUp", "AnyDown") end
    box:SetScript("OnClick", function() end)   -- the click lands here, not on Release
    box.bg = box:CreateTexture(nil, "BACKGROUND"); box.bg:SetAllPoints(box); box.bg:SetColorTexture(0, 0, 0, 1)
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.text:SetPoint("CENTER", box, "CENTER", 0, 0)
    box.text:SetJustifyH("CENTER")
    box:Hide()
    return box
end

-- the box over the shown DEATH dialog's Release button (the text: hers, and this death's flavour under it)
local function Cover(dialog)
    local c = Cfg()
    if not (c and c.enabled) then Hide(); state.why = "off"; return end
    if Ghost() then Hide(); state.why = "a ghost"; return end
    if not LoadsHere(c) then Hide(); state.why = "not loaded here (Load: " .. LoadText(c.load) .. ")"; return end
    local b1 = dialog and dialog.GetButton1 and dialog:GetButton1()
    if type(b1) ~= "table" then Hide(); state.why = "the death window has no Release button"; return end
    local f = Build()
    f:SetFrameStrata(STRATA)
    f:ClearAllPoints()
    f:SetAllPoints(b1)
    if f.SetFrameLevel and dialog.GetFrameLevel then f:SetFrameLevel((dialog:GetFrameLevel() or 1) + 20) end
    local list = Flavors(c)
    local flav = (c.flavorOn and #list > 0) and list[((c.index - 1) % #list) + 1] or nil
    f.text:SetText(c.text .. (flav and ("\n" .. flav) or ""))
    local col = Theme("xui-label", "text", { 1, 0.82, 0, 1 })
    f.text:SetTextColor(col[1], col[2], col[3], 1)
    f.flavor = flav
    state.dialog = dialog
    state.why = "covered"
    if ModDown(c) then f:Hide() else f:Show() end
    ev:RegisterEvent("MODIFIER_STATE_CHANGED")
    if dialog.HookScript and not dialog.xuiReleaseHooked then
        dialog.xuiReleaseHooked = true
        dialog:HookScript("OnHide", function(self) if state.dialog == self then Hide() end end)   -- (returns at once when not ours)
    end
end
local function FindDeath() return type(StaticPopup_FindVisible) == "function" and StaticPopup_FindVisible("DEATH") or nil end
-- (QoL 0.7.39; standing rule V21: every change has an in-game QA walkthrough) read-only state for Dev Assist's walkthrough
-- (XayaUI_DevAssist/QAWalks-display.lua), reached through core's services, never by name
-- D8 adds Page / Apply / LoadsHere / LoadText for XayaUI_Options (Rules > Raid Rules) and Dev Assist's D8 walkthrough; one service.
if ns.Provide then ns.Provide("releaseGuard", { Cfg = function() return Cfg() end,
    State = function() return state end, Box = function() return box end, Death = function() return FindDeath() end,
    Page = function(notify) return ns.BuildReleaseGuardPage(notify) end, Apply = function() return ns.ReleaseGuard_Apply() end,
    LoadsHere = function() return ns.ReleaseGuard_LoadsHere() end, LoadText = function(L) return LoadText(L) end }) end

local function OnEvent(_, event)
    local c = Cfg()
    if not (c and c.enabled) then Hide(); return end
    if event == "PLAYER_DEAD" then
        -- each death: the next flavour text of her list (her answer "Each death")
        c.index = c.index + 1
        state.death = state.death + 1
        local d = FindDeath()
        if d then Cover(d) end
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        if Ghost() or event == "PLAYER_UNGHOST" or not (R(UnitIsDeadOrGhost, "player") == true) then Hide() end
    elseif event == "MODIFIER_STATE_CHANGED" then
        if state.dialog and box then
            if ModDown(c) then box:Hide() elseif not Ghost() then box:Show() end
        end
    end
end

function ns.ReleaseGuard_Apply()
    local c = Cfg()
    if not c then return end
    if not c.enabled then
        if ev then ev:UnregisterAllEvents() end
        Hide()
        return
    end
    if not ev then ev = CreateFrame("Frame"); ev:SetScript("OnEvent", OnEvent) end
    ev:RegisterEvent("PLAYER_DEAD"); ev:RegisterEvent("PLAYER_ALIVE"); ev:RegisterEvent("PLAYER_UNGHOST")
    if not hooked and type(hooksecurefunc) == "function" and type(StaticPopup_Show) == "function" then
        hooked = true
        -- post-hook: when the game shows its DEATH window, cover its Release button (returns at once while the guard is off; /reload
        -- removes it fully)
        hooksecurefunc("StaticPopup_Show", function(which)
            if which ~= "DEATH" then return end
            local c2 = Cfg()
            if not (c2 and c2.enabled) then return end
            local d = FindDeath()
            if d then Cover(d) end
        end)
    end
    local d = FindDeath()
    if d and d.IsShown and d:IsShown() then Cover(d) end
end
ns.WhenReady(function() local c = Cfg(); if c and c.enabled then ns.ReleaseGuard_Apply() end end)

-- options: its settings page, shown under Rules > Raid Rules > Release Guard (Options builds the entry, its Load tab and its on / off;
-- D8: moved out of the QoL tab, Xaya: "It belongs in "Raid Rules" under rules")
function ns.BuildReleaseGuardPage(Notify)
    local function C() return Cfg() or ns.RELEASEGUARD_DEFAULTS end
    local function Changed() ns.ReleaseGuard_Apply(); if Notify then Notify() end end
    local isOff = function() return not C().enabled end
    return {
        type = "group", name = "Settings", order = 1,
        xuiSwitch = { type = "toggle", name = "Release Guard", tip = "Covers Release Spirit when you die, so a misclick can't release you.",
            desc = "A black box over the death window's Release Spirit button. While it is off nothing is created or listened to; once it has been on, a /reload removes its hook fully (while off it does nothing).",
            get = function() return C().enabled and true or false end,
            set = function(_, v) C().enabled = v and true or false; Changed() end },
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "When you die, a black box covers the Release Spirit button so a misclick does not release you. Hold the key below and the box steps aside so your click reaches Release. Hidden as a ghost. Off by default. Where it works is set on its Load tab (by default: in a raid with at least 20 people in your group)." },
            text = { type = "input", order = 1, width = "double", name = "Text on the box", disabled = isOff,
                get = function() return C().text end, set = function(_, v) v = tostring(v or ""); C().text = (v ~= "") and v or "NO RELEASE"; Changed() end },
            flavorOn = { type = "toggle", order = 2, width = "full", name = "Flavour text under it (the next one each death)", disabled = isOff,
                get = function() return C().flavorOn end, set = function(_, v) C().flavorOn = v and true or false; Changed() end },
            flavors = { type = "input", order = 3, width = "full", multiline = 6, name = "Flavour texts (one per line, in order)", disabled = function() return isOff() or not C().flavorOn end,
                get = function() return C().flavors end, set = function(_, v) C().flavors = tostring(v or ""); Changed() end },
            modifier = { type = "select", order = 4, name = "Key to click through", values = MODS, sorting = { "SHIFT", "CTRL", "ALT" }, disabled = isOff,
                desc = "Hold it and the box steps aside so the click reaches Release Spirit.",
                get = function() return C().modifier end, set = function(_, v) C().modifier = v; Changed() end },
        },
    }
end
-- (not registered on the QoL tab any more: Options shows it under Rules > Raid Rules, D8; other addons reach it through the service)

-- /xui releaseguard: what it did at the last death and what the game shows now (UI-57: to settle the inference above in the game)
ns.RegisterCommand({ "releaseguard", "rg" }, function()
    local c = Cfg()
    if not c then return end
    local inInst, kind = R(IsInInstance)
    local d = FindDeath()
    local function lv(fr) if not fr then return "-" end; local ok, st = pcall(fr.GetFrameStrata, fr); local ok2, l = pcall(fr.GetFrameLevel, fr)
        return ("%s %s"):format(ok and tostring(st) or "?", ok2 and tostring(l) or "?") end
    ns.Print(("Release Guard: %s; Load: %s (works here: %s); here: %s; ghost %s; key %s held %s."):format(c.enabled and "on" or "off", LoadText(c.load), tostring(LoadsHere(c)),
        IsSecret(inInst) and "unknown" or (inInst and tostring(kind) or "not in an instance"), tostring(Ghost()), tostring(MODS[c.modifier]), tostring(ModDown(c))))
    ns.Print(("  last death: %s; deaths seen %d; death window %s (%s); box %s (%s)."):format(tostring(state.why), state.death,
        d and (d:IsShown() and "shown" or "hidden") or "not shown", lv(d), box and (box:IsVisible() and "visible" or "hidden") or "never made", lv(box)))
end, "/xui releaseguard (Release Guard: what it did at the last death)")
