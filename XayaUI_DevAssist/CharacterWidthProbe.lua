-------------------------------------------------------------------------------
-- CharacterWidthProbe.lua : /xui debug widthprobe [px | off] (XayaUI QoL 0.7.12). An in-game test, run only when typed, for the planned
-- QoL Character Reskin's "wider character viewport" (Xaya, 2026-11-04, her answer to plan question 5: "a wider character viewport").
-- The plan (docs/plans/STAT-CALCULATOR-REDESIGN-2026-11-04.md) says a probe comes before anything is built, because changing a UI
-- panel's width from addon code may taint the game's panel placement (INFERENCE; not checked). This file only measures; it builds
-- nothing permanent and is not loaded into any switch.
--
-- What Blizzard does (live 12.1.5 source, Blizzard_UIPanels_Game/Mainline, read 2026-11-04):
--   CharacterFrame.lua CharacterFrameMixin:UpdateSize(): SetWidth(PANEL_DEFAULT_WIDTH, or 540 with the stats pane open); for the
--     paper doll the Inset's BOTTOMRIGHT is pinned at BOTTOMLEFT + PANEL_DEFAULT_WIDTH + PANEL_INSET_RIGHT_OFFSET; then, when the
--     width changed, UpdateUIPanelPositions(self).
--   PaperDollFrame.xml: CharacterHandsSlot (the right slot column) hangs from the Inset's TOPRIGHT; CharacterFrame.xml: InsetRight (the
--     stats pane) from the Inset's TOPRIGHT; CharacterModelScene is a fixed 231 x 320 at TOPLEFT 52, -66; CharacterMainHandSlot is
--     at BOTTOMLEFT 130, 16.
-- The probe, out of combat, with the character window open: widens the window by px, moves the Inset's right edge out by px (so
-- the right column and the stats pane follow), widens the model scene by px, moves the main hand slot right by px / 2, and asks the
-- game to place its panels again (UpdateUIPanelPositions). While it runs it prints every ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN
-- the game raises (events.md:34-35: isTainted, function), which is what taint would show as. "off" puts the window back through
-- Blizzard's own UpdateSize and restores the model and the slot. A /reload clears anything left.
-------------------------------------------------------------------------------
-- (Dev Assist 0.7.5: moved here from XayaUI_QoL; REQUEST-LOG #81. Registered as /xui debug widthprobe by CoreDebug.lua.)
local ns = rawget(_G, "XayaUI_NS")
if type(ns) ~= "table" then return end

local probe = { on = false, blocked = 0 }
ns.CharWidthProbe = probe   -- for the tests

local function Say(msg) if ns.Print then ns.Print("width probe: " .. msg) end end

local function OnBlocked(_, event, isTainted, fn)
    probe.blocked = probe.blocked + 1
    local t = (GetTime and GetTime()) or 0
    Say(("%s at %.1f s: %s, %s"):format(event, t, tostring(isTainted), tostring(fn)))
end

local function Restore()
    local cf = _G.CharacterFrame
    if probe.modelW and _G.CharacterModelScene and _G.CharacterModelScene.SetWidth then pcall(_G.CharacterModelScene.SetWidth, _G.CharacterModelScene, probe.modelW) end
    local mh, p = _G.CharacterMainHandSlot, probe.mainHand
    if mh and p then pcall(function() mh:ClearAllPoints(); mh:SetPoint(p[1], p[2], p[3], p[4], p[5]) end) end
    if cf and cf.UpdateSize then pcall(cf.UpdateSize, cf) end   -- Blizzard's own sizing puts the width and the Inset back
end

function ns.CharWidthProbe_Run(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "off" then
        if not probe.on then Say("not running."); return end
        if InCombatLockdown and InCombatLockdown() then Say("leave combat first."); return end
        Restore()
        if probe.ev then probe.ev:UnregisterAllEvents() end
        probe.on = false
        Say(("off. %d blocked-action message%s while it ran. Please /reload now, then report what you saw."):format(probe.blocked, probe.blocked == 1 and "" or "s"))
        return
    end
    if probe.on then Say("already running; /xui debug widthprobe off first."); return end
    -- (QoL 0.7.22) the Character Reskin's "Wider window" is built on what this probe tested; the two would widen the window twice
    local wide = ns.Service and ns.Service("characterReskin")   -- (XayaUI QoL's, through the service list)
    if wide and wide.WideOn and wide.WideOn() then
        Say("the Character Reskin's wider window is on (Blizzard Reskin > Character Pane); turn it off there first."); return
    end
    if InCombatLockdown and InCombatLockdown() then Say("not in combat: try again out of combat."); return end
    local cf, mdl, mh = _G.CharacterFrame, _G.CharacterModelScene, _G.CharacterMainHandSlot
    if not (cf and cf.IsShown and cf:IsShown() and _G.PaperDollFrame and _G.PaperDollFrame:IsShown()) then
        Say("open the character window on its Character tab first (C)."); return
    end
    local DW, RO, BO = _G.PANEL_DEFAULT_WIDTH, _G.PANEL_INSET_RIGHT_OFFSET, _G.PANEL_INSET_BOTTOM_OFFSET
    if not (type(cf.Inset) == "table" and cf.Inset.SetPoint and type(DW) == "number" and type(RO) == "number" and type(BO) == "number") then
        Say("the game's character window is not built the way this probe expects (no Inset or panel sizes); nothing changed."); return
    end
    local px = math.floor(tonumber(arg) or 120)
    px = math.max(40, math.min(300, px))
    probe.blocked = 0
    probe.ev = probe.ev or CreateFrame("Frame")
    probe.ev:SetScript("OnEvent", OnBlocked)
    pcall(probe.ev.RegisterEvent, probe.ev, "ADDON_ACTION_BLOCKED")
    pcall(probe.ev.RegisterEvent, probe.ev, "ADDON_ACTION_FORBIDDEN")
    local w0 = cf:GetWidth()
    probe.modelW = mdl and mdl.GetWidth and mdl:GetWidth() or nil
    if mh and mh.GetPoint then local a, b, c, d, e = mh:GetPoint(1); if a then probe.mainHand = { a, b, c, d or 0, e or 0 } end end
    probe.on = true
    local steps = {}
    local function Step(name, fn) local ok, err = pcall(fn); steps[#steps + 1] = name .. (ok and " ok" or (" FAILED (" .. tostring(err) .. ")")) end
    Step("window width", function() cf:SetWidth(w0 + px) end)
    Step("inset edge", function() cf.Inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", DW + RO + px, BO) end)
    if mdl and probe.modelW then Step("model width", function() mdl:SetWidth(probe.modelW + px) end) end
    if mh and probe.mainHand then
        local p = probe.mainHand
        Step("main hand slot", function() mh:ClearAllPoints(); mh:SetPoint(p[1], p[2], p[3], p[4] + math.floor(px / 2), p[5]) end)
    end
    if type(UpdateUIPanelPositions) == "function" then
        if ns.MapTrace then ns.MapTrace("width probe: UpdateUIPanelPositions(CharacterFrame)") end
        Step("panel placement", function() UpdateUIPanelPositions(cf) end)
    end
    Say(("on, %d px wider (%d -> %d). %s."):format(px, math.floor(w0 + 0.5), math.floor(cf:GetWidth() + 0.5), table.concat(steps, ", ")))
    Say("1) Look: right-hand slots and the stats pane moved out, model wider, weapons centered?")
    Say("2) With it open, press P (spellbook) and N (talents): do they sit beside it without overlapping?")
    Say("3) Fight a training dummy; open and close your bags, the spellbook and the map in combat; leave combat.")
    Say("4) Watch chat for 'width probe: ADDON_ACTION_...' lines or Blizzard's 'Interface action failed because of an AddOn'.")
    Say("5) Switching the window's tabs puts Blizzard's width back (expected). Then type /xui debug widthprobe off and /reload.")
end
