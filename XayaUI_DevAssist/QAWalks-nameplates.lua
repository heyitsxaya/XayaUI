-------------------------------------------------------------------------------
-- QAWalks-nameplates.lua (XayaUI_DevAssist 0.7.14; 0.7.32 adds the Blizzard options walkthrough): in-game QA walkthrough for XayaUI Nameplates 0.1.0, Target colour (slice 1 of
-- docs/plans/NAMEPLATES-PLAN-2026-11-07.md; QA-CHECKLIST K1-K4; REQUEST-LOG A15 NP-1).
-- V20 / V22 (Xaya): a walkthrough with pre-filled answers wherever the addon can read the result (prefill = true: the addon's verdict
-- is offered on one Accept button; nothing is recorded without her click). What only eyes can judge (is the colour visible, is the
-- health text still readable, does the plate look laid out right) is a question step (noVerdict).
-- It reads XayaUI Nameplates only through its service (Core.lua: ns.Provide("nameplates", NP)); with that addon not loaded, the
-- first step says how to turn it on. The walkthrough remembers the two settings it changes and puts them back in its last step.
-- Listed in XayaUI_DevAssist.toc after QAWalks.lua. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NP() local ns = rawget(_G, "XayaUI_NS"); return ns and ns.Service and ns.Service("nameplates") end
local function TC() local np = NP(); return np and np.TargetColor end
local function Near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.01 end

-- the colour of the texture now shown on the target's plate (nil when none is shown)
local function ShownColour()
    local tc = TC(); if not (tc and tc.Shown) then return nil end
    local t, bar = tc.Shown()
    if not (t and t.IsShown and t:IsShown()) then return nil end
    local ok, r, g, b = pcall(t.GetVertexColor, t)
    if not ok then return nil end
    return r, g, b, bar
end

local saved, firstBar   -- the settings this walkthrough changes; the bar coloured in the "target a mob" step
local function Remember() local np = NP(); if not np then return end; local d = np.DB(); saved = { on = d.targetColor, color = { d.color[1], d.color[2], d.color[3] } } end
local function PutBack()
    local np = NP(); if not (np and saved) then return end
    local d = np.DB(); d.targetColor = saved.on; d.color = { saved.color[1], saved.color[2], saved.color[3] }
    np.TargetColor.Apply()
end

local function Ready()
    local np = NP()
    if not np then return false, "XayaUI Nameplates is not loaded: enable it in the AddOns list (character select or Esc > AddOns), then /reload" end
    local rep = np.Replacer()
    if rep then return false, rep .. " is loaded and replaces Blizzard's nameplates: disable it in the AddOns list, then /reload" end
    return true
end

QA.Register("nameplates-target-colour", { title = "Nameplates: target color (XayaUI Nameplates 0.1.0)", qa = "K1-K4, NP-1", order = 300, prefill = true, steps = {
    { text = "Enable |cffffd100XayaUI Nameplates|r and disable |cffffd100Plater|r in the AddOns list, then /reload and open this walkthrough again. Then press |cffffd100Do it for me|r: XayaUI remembers your Nameplates settings (the last step puts them back) and switches Target color on.\n\n|cffffd100Expect:|r the addon's check says XayaUI Nameplates is loaded, no other nameplate addon is, and Target color is on.",
        setup = function() Remember(); local np = NP(); if np then np.DB().targetColor = true; np.TargetColor.Apply() end end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local tc = TC()
            if not (NP().DB().targetColor and tc.Listening()) then return false, "Target color is off (press Do it for me)" end
            return true, "loaded, Blizzard's nameplates in use, Target color on and listening"
        end },
    { text = "Out of combat, target an enemy that shows a nameplate (any mob in the open world).\n\n|cffffd100Expect:|r the filled part of its health bar turns teal (dark blue-green). The other plates keep their color.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local r, g, b, bar = ShownColour()
            if not r then return false, "no color shown: " .. TC().Report() end
            firstBar = bar
            local np = NP(); local cr, cg, cb = np.Color()
            if not (Near(r, cr) and Near(g, cg) and Near(b, cb)) then return false, ("shown in %.2f %.2f %.2f, setting is %.2f %.2f %.2f"):format(r, g, b, cr, cg, cb) end
            return true, "your target's plate is colored, in the set color"
        end },
    { text = "Look at the teal bar.\n\n|cffffd100Answer:|r is the color clearly visible, and are the name and health text (if you show it) still readable on top of it? Pass if yes; Fail and say what is covered.",
        noVerdict = true },
    { text = "Target a different enemy (Tab).\n\n|cffffd100Expect:|r the new target's bar is teal; the first one is back to its normal color.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local r, _, _, bar = ShownColour()
            if not r then return false, "no color shown: " .. TC().Report() end
            if bar == firstBar then return false, "still the same plate (target a different mob)" end
            return true, "the color moved to the new target; only one plate is colored"
        end },
    { text = "Now the real test: |cffffd100in combat|r, ideally in a dungeon or Mythic+ pull. Switch targets a few times while fighting. Leave this window open (it can sit at the side).\n\n|cffffd100Expect:|r every new target turns teal at once, and no \"Interface action failed\" or \"blocked\" message appears. Press Check while you are still in combat with a target.",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local inCombat = InCombatLockdown and InCombatLockdown()
            if not inCombat then return false, "not in combat right now (press Check during the fight)" end
            local r = ShownColour()
            if not r then return false, "in combat, but no color shown: " .. TC().Report() end
            local inInst, kind = false, nil
            if IsInInstance then inInst, kind = IsInInstance() end
            return true, "in combat, target colored" .. (inInst and (" (inside an instance: " .. tostring(kind) .. ")") or " (open world)")
        end },
    { text = "Press |cffffd100Do it for me|r: the color is set to magenta (a test color). Keep a target selected.\n\n|cffffd100Expect:|r your target's bar turns magenta. (You can choose your own color later in /xui > QoL > Nameplates; the Teal button puts teal back.)",
        setup = function() local np = NP(); if np then np.DB().color = { 1, 0, 1 }; np.TargetColor.Apply() end end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local r, g, b = ShownColour()
            if not r then return false, "no color shown (target a mob): " .. TC().Report() end
            if not (Near(r, 1) and Near(g, 0) and Near(b, 1)) then return false, ("shown in %.2f %.2f %.2f, not magenta"):format(r, g, b) end
            return true, "the new color is shown on the target"
        end },
    { text = "Press |cffffd100Do it for me|r: Target color is switched off.\n\n|cffffd100Expect:|r the colored bar goes back to normal at once, and switching targets colors nothing.",
        setup = function() local np = NP(); if np then np.DB().targetColor = false; np.TargetColor.Apply() end end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            if TC().Listening() then return false, "still listening for target changes" end
            if ShownColour() then return false, "a color is still shown" end
            return true, "off: nothing shown, nothing listening"
        end },
    { text = "Look at a few enemy plates (Blizzard's own, now that Plater is off). Plater's \"Reorder Nameplate\" mod put the health bar in the middle, the cast bar right under it and the auras above it.\n\n|cffffd100Answer:|r is that the order you see on Blizzard's plates? Pass if yes; Fail and say what differs (sizes are expected to differ: Blizzard offers size steps, not pixels).",
        noVerdict = true },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put your Nameplates settings back as they were before this walkthrough. Then press |cffffd100Done|r. (To go back to Plater later: enable it and disable XayaUI Nameplates in the AddOns list, then /reload.)",
        setup = PutBack,
        check = function()
            local np = NP(); if not np then return false, "XayaUI Nameplates is not loaded" end
            if not saved then return false, "nothing was remembered (run the walkthrough from its first step)" end
            local d = np.DB()
            if d.targetColor ~= saved.on then return false, "Target color not put back yet" end
            for i = 1, 3 do if not Near(d.color[i], saved.color[i]) then return false, "color not put back yet" end end
            return true, "settings are back as they were"
        end },
} })

-- (Nameplates 0.2.0) Match my Plater settings: Blizzard's own nameplate options set to her Plater profile, and Put back (QA-CHECKLIST K5)
local function BO() local np = NP(); return np and np.BlizzardOptions end
QA.Register("nameplates-blizzard-options", { title = "Nameplates: match my Plater settings (XayaUI Nameplates 0.2.0)", qa = "K5, NP-1", order = 301, prefill = true, steps = {
    { text = "Out of combat, press |cffffd100Do it for me|r (the same as the |cffffd100Match my Plater settings|r button in /xui > QoL > Nameplates).\n\n|cffffd100Expect:|r the addon's check says every listed Blizzard option now matches your Plater profile (health percent and amount, elite icon, spell name / icon / target on cast bars, important casts highlighted, threat color and glow on, threat flash off, debuffs and crowd control on enemies).",
        setup = function() local bo = BO(); if bo then local _, msg = bo.Apply(); local np = NP(); np.lastBlizz = msg end end,
        check = function()
            local bo = BO(); if not bo then return false, "XayaUI Nameplates 0.2.0 is not loaded" end
            local m, k, n = bo.Matching()
            if k < n then return false, ("%d of %d options could not be read back"):format(n - k, n) end
            if m < n then return false, ("%d of %d match: %s"):format(m, n, tostring(NP().lastBlizz)) end
            return true, ("all %d options match your Plater profile"):format(n)
        end },
    { text = "Target a few enemies and watch a caster.\n\n|cffffd100Answer:|r do you see the health percent and amount on the bars, the cast target's name, and important casts highlighted? Pass if yes; Fail and say what is missing.",
        noVerdict = true },
    { text = "Out of combat, press |cffffd100Do it for me|r (the same as |cffffd100Put back|r).\n\n|cffffd100Expect:|r Blizzard's nameplate options are back to what they were before the first Match.",
        setup = function() local bo = BO(); if bo then local _, msg = bo.PutBack(); local np = NP(); np.lastBlizz = msg end end,
        check = function()
            local np = NP(); if not (np and BO()) then return false, "XayaUI Nameplates 0.2.0 is not loaded" end
            if type(np.DB().blizzBefore) == "table" then return false, "not put back: " .. tostring(np.lastBlizz) end
            return true, tostring(np.lastBlizz)
        end },
} })
