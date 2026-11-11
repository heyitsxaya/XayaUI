-------------------------------------------------------------------------------
-- QAWalks-charreskin-gate.lua (XayaUI Dev Assist): the in-game walkthrough for the V27 gate fixes of Character Reskin
-- (XayaUI_QoL/CharacterReskin.lua; gate findings G-009 and G-021, unit U4-character-reskin).
--   G-009: Extra height spreads the slot columns in whole pixels (every gap math.floor(px / 7), the top px % 7 gaps of each column one
--          more); every slot's y offset is a whole number and ns.CharReskin_TallGap answers a whole number.
--   G-021: the lasting slot / stat redraw hooks test whether the character window is shown first and reuse the look's answer worked out
--          at ns.CharReskin_Apply; ns.CharReskinDiag.lookReads counts the times it was worked out (it should not move on redraws).
-- Standing rule V22 (Xaya 2026-11-07): the addon offers its own verdict where it can read the result (prefill = true; recorded only on
-- her click) and captures what it reads into the step's note. Listed in XayaUI_DevAssist.toc after QAWalks-chardisplay-fixes.lua;
-- does nothing without the framework. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local COLS = { { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" },
    { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" } }
local function InCombat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function WindowShown()
    local cf = rawget(_G, "CharacterFrame")
    local ok, v = pcall(function() return cf and cf:IsShown() end)
    return (ok and v) and true or false
end
local function Ready()
    local ns = NS()
    if not (ns and ns.CharReskin_Cfg and ns.CharReskin_TallGap and ns.CharReskinDiag) then return nil, "XayaUI QoL is off or older than this change" end
    if ns.CharReskinDiag.lookReads == nil and not ns.CharReskin_TallGapAt then return nil, "XayaUI QoL is older than this change (no gate counters)" end
    return ns
end
-- every slot's y offset (TOPLEFT on the slot above), read from the game; whole = every one a whole number
local function Offsets()
    local out, whole = {}, true
    for _, col in ipairs(COLS) do
        for i = 2, #col do
            local b = rawget(_G, "Character" .. col[i])
            local ok, _, _, _, _, y = pcall(function() return b:GetPoint(1) end)
            if ok and type(y) == "number" then
                out[#out + 1] = ("%g"):format(y)
                if y ~= math.floor(y) then whole = false end
            else
                out[#out + 1] = "?"; whole = false
            end
        end
    end
    return whole, table.concat(out, ",")
end

local savedTall, baseReads

QA.Register("charreskin-gate", { title = "Character Reskin: Extra height in whole pixels; slot and stat redraws do no settings work (G-009, G-021)",
    area = "QoL", qa = "E1z240", order = 529, prefill = true, steps = {
    { text = "Out of combat, with |cffffd100Blizzard UI Reskin > Character Reskin|r and its |cffffd100Wider window|r on, press |cffffd100Do it for me|r: it sets |cffffd100Extra height|r to 20 px (your value is put back at the end). Open the character window (C) and press |cffffd100Check|r.\n\n|cffffd100Expect:|r the window is 20 px taller, the slots spread evenly, and every slot's offset is a whole number.",
      setup = function()
          local ns = Ready()
          if not ns or InCombat() then return end
          local c = ns.CharReskin_Cfg()
          if not c then return end
          if savedTall == nil then savedTall = c.tallPx or 0 end
          c.tallPx = 20
          ns.CharReskin_Apply()
      end,
      check = function()
          local ns, why = Ready()
          if not ns then return nil, why end
          if InCombat() then return nil, "leave combat, then check" end
          if not WindowShown() then return nil, "open the character window (C), then check" end
          local c = ns.CharReskin_Cfg() or {}
          local whole, list = Offsets()
          local gap = ns.CharReskin_TallGap()
          local note = ("Extra height %s; slot offsets %s; gap every pair has at least %s; status: %s"):format(tostring(c.tallPx), list,
              tostring(gap), tostring(ns.CharReskinDiag.tall))
          if c.tallPx ~= 20 then return nil, "press Do it for me first | " .. note end
          if not (ns.CharReskin_Active and ns.CharReskin_Active()) or c.wide ~= true then return nil, "turn Character Reskin and its Wider window on, then check | " .. note end
          return whole and gap == math.floor(gap) and gap == 2, note
      end },
    { text = "Keep the window open and press |cffffd100Do it for me|r (it notes the counter). Swap a ring or trinket off and back on twice, then close the window (C) and swap it off and back on again, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the look's answer was not worked out again by any of those redraws (the counter did not move).",
      setup = function()
          local ns = Ready()
          baseReads = ns and ns.CharReskinDiag.lookReads or nil
      end,
      check = function()
          local ns, why = Ready()
          if not ns then return nil, why end
          if baseReads == nil then return nil, "press Do it for me first (it notes the counter)" end
          local now = ns.CharReskinDiag.lookReads or 0
          local note = ("worked out %d time(s) since Do it for me (total %d); character window %s"):format(now - baseReads, now,
              WindowShown() and "open" or "closed")
          if WindowShown() then return nil, "close the character window and swap the item once more, then check | " .. note end
          return now == baseReads, note
      end },
    { text = "Open the character window again. Your look: are the slot borders and the item level / enchant text beside them sharp (no blurry or doubled edge) with Extra height 20? Pass if yes; Fail and say which slot.", noVerdict = true },
    { done = true, text = "Press |cffffd100Do it for me|r to put your Extra height back (out of combat), then |cffffd100Done|r.",
      setup = function()
          local ns = Ready()
          if not ns or InCombat() or savedTall == nil then return end
          local c = ns.CharReskin_Cfg()
          if c then c.tallPx = savedTall; ns.CharReskin_Apply() end
          savedTall = nil
      end },
} })
