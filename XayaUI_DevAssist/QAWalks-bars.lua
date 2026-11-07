-------------------------------------------------------------------------------
-- QAWalks-bars.lua (XayaUI_DevAssist 0.7.14): in-game QA walkthrough for Bar cues (core 0.6.58 / Options 0.6.59 / Bonus 0.6.20,
-- ROADMAP RM-BARS, REQUEST-LOG A11 S8-1 .. S8-13; QA B200-B210, F21).
-- Xaya's standing rules: V20 (walkthroughs in /xui dev qa) and, relayed 2026-11-07, "make sure every feature or significant change to
-- the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
-- So: prefill = true (QAWalk.lua: the addon's own verdict is offered on one button, Accept; nothing is recorded without the click), and
-- every check reads the real frames and settings: the bar's size, background, icon, spark, name, its moving value, its colour and
-- why, the colour style (the cue's own and a group's that forces one), the texture list, whether the combat engine draws it, and
-- Enhanced Tooltips' Type colours. What only eyes can judge (how it looks, combat) says so and is a noVerdict step.
-- "Do it for me" makes a test rule ("XayaUI QA: Bar test") on a buff you have right now, previews it, and the last step removes the
-- rule, its cue and the test group again. Nothing else of yours is changed.
-- Listed in XayaUI_DevAssist.toc after QAWalks-chat.lua; does nothing without the framework or XayaUI's Bar cues. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local RULE_NAME, GROUP_NAME = "XayaUI QA: Bar test", "XayaUI QA: Bar group"
local T = {}   -- this walkthrough's own test objects: rule, cue, group, the value seen at the drain step

local function Ready()
    local ns = NS()
    if not (ns and ns.BarCueSettings and ns.NewCueRule) then return false, "XayaUI's Bar cues are not loaded (core 0.6.58 or later)" end
    return true
end
local function Frame() local ns = NS(); return T.cue and ns and ns.DisplayFrame and ns.DisplayFrame(T.cue) or nil end
local function Num(v) if type(v) == "number" and not (rawget(_G, "issecretvalue") and issecretvalue(v)) then return v end end
local function Near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 0.01) end

-- a buff you have now (out of combat the game lets addon code read it), else nil
local function CurrentBuff()
    local CU = rawget(_G, "C_UnitAuras")
    if not (CU and CU.GetAuraDataByIndex) then return nil end
    for i = 1, 40 do
        local ok, a = pcall(CU.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not (ok and type(a) == "table") then break end
        local id = Num(a.spellId)
        if id and id > 0 then return id, a.name end
    end
end

local function MakeRule()
    local ns = NS()
    if T.rule then return end
    local P = ns.NewRule()
    P.name, P.enabled = RULE_NAME, true
    local id = CurrentBuff()
    P.useBuff, P.buffID, P.buffState = true, id or 0, "present"
    if ns.NormalizeRule then ns.NormalizeRule(P) end
    ns.rules[#ns.rules + 1] = P
    T.rule = P
    T.cue = ns.NewCueRule(P, "bar")
    T.buff = id
    if ns.SetPreview then ns.SetPreview({ T.cue }, "visual", true) end
    if ns.RefreshVisual and T.cue then pcall(ns.RefreshVisual, T.cue) end
    if ns.MarkDirty then ns.MarkDirty() end
end
local function RemoveAll()
    local ns = NS()
    if not ns then return end
    if T.cue and ns.SetPreview then ns.SetPreview({ T.cue }, "visual", false) end
    for i = #ns.rules, 1, -1 do
        local r = ns.rules[i]
        if r == T.rule or r == T.cue then
            if ns.DropVisual then pcall(ns.DropVisual, r) end
            table.remove(ns.rules, i)
        end
    end
    if T.group then
        for i = #ns.folders, 1, -1 do if ns.folders[i] == T.group then table.remove(ns.folders, i) end end
    end
    T.rule, T.cue, T.group, T.v0 = nil, nil, nil, nil
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
    if ns.MarkDirty then ns.MarkDirty() end
end

-- the bar's drawn colour: the game's own read where it answers, else what XayaUI last painted
local function DrawnColor(fr)
    local bar = fr and fr.barF
    if not bar then return nil end
    if bar.GetStatusBarColor then
        local ok, r, g, b = pcall(bar.GetStatusBarColor, bar)
        if ok and Num(r) and Num(g) and Num(b) then return r, g, b end
    end
    return fr.barCR, fr.barCG, fr.barCB
end

local steps = {
    { text = "Press |cffffd100Do it for me|r: it makes a test rule, \"" .. RULE_NAME .. "\", on a buff you have right now, with one |cffffd100Bar|r cue, and shows it as a preview. "
        .. "|cffffd100Expect:|r a bar 220 x 22 near the middle of the screen: a faint black background, a 1 px black border, the buff's icon at the left, its name at the left inside the bar, a time at the right.",
      setup = function() local ok = Ready(); if ok then MakeRule() end end,
      check = function()
          local ok, why = Ready(); if not ok then return false, why end
          if not T.cue then return false, "press Do it for me first" end
          local fr = Frame()
          if not (fr and fr.barF) then return false, "the Bar cue has no bar on its display" end
          local v = T.cue.visual
          local bad = {}
          if not (v.w == 220 and v.h == 22) then bad[#bad + 1] = ("size %sx%s, not 220x22"):format(tostring(v.w), tostring(v.h)) end
          if not (v.bg and v.bg.enabled and Near(v.bg.color and v.bg.color[4], 0.2)) then bad[#bad + 1] = "background is not black at 20 %" end
          if not (v.border and v.border.enabled and v.border.size == 1) then bad[#bad + 1] = "border is not 1 px" end
          if fr.tex and fr.tex.IsShown and fr.tex:IsShown() then bad[#bad + 1] = "the picture layer is showing over the bar" end
          if not (fr.barIcon and fr.barIcon:IsShown()) then bad[#bad + 1] = "no icon" end
          if not (fr.barName and fr.barName:IsShown()) then bad[#bad + 1] = "no name text" end
          if #bad > 0 then return false, table.concat(bad, "; ") end
          return true, "220 x 22, background 20 %, 1 px border, icon, name" .. (T.buff and (" (buff " .. T.buff .. ")") or " (no buff found: preview only)")
      end },
    { text = "Watch the bar for a few seconds. |cffffd100Expect:|r it drains smoothly toward the left (the preview's sample timer counts down from 12.3 s and starts again), with a bright spark on the right edge of the fill. Then press Accept or Pass / Fail.",
      setup = function() local fr = Frame(); T.v0 = fr and fr.barF and Num(fr.barF:GetValue()); T.t0 = GetTime() end,
      check = function()
          local fr = Frame()
          if not (fr and fr.barF) then return false, "no test bar (step 1)" end
          local v = Num(fr.barF:GetValue())
          if not v then return false, "the bar's value cannot be read" end
          if not (v >= 0 and v <= 1) then return false, ("value %.3f is outside 0..1"):format(v) end
          if not fr:GetScript("OnUpdate") and not fr.barTimed then return false, "nothing moves the bar (no per-frame update, no game timer)" end
          if T.v0 and (GetTime() - (T.t0 or 0)) > 0.3 and Near(v, T.v0, 0.0001) then return false, "the value has not changed since Do it for me" end
          return true, ("value %.2f, moving"):format(v)
      end },
    { text = "Look at the bar's colour. Open the test rule's Cues tab (Rules list) > Bar Options > Colour: the |cffffd100Now:|r line says which colour it uses and why (the type the tooltip names, e.g. \"Fire Damage\", else the aura's dispel type, else blue). "
        .. "|cffffd100Expect:|r the bar has that colour.",
      check = function()
          local ns, fr = NS(), Frame()
          if not (fr and fr.barF) then return false, "no test bar (step 1)" end
          local r, g, b, _, why, t = ns.BarCueColor(T.cue, nil)
          local dr, dg, db = DrawnColor(fr)
          if not (Near(dr, r, 0.02) and Near(dg, g, 0.02) and Near(db, b, 0.02)) then return false, "the bar is not drawn in the colour XayaUI chose" end
          local what = (why == "tooltip" and ("named in the tooltip: " .. tostring(t))) or (why == "dispel" and ("the aura's dispel type: " .. tostring(t))) or (why == "fixed" and "a fixed colour") or "no type found: the fixed blue"
          return true, "drawn in the chosen colour (" .. what .. ")"
      end },
    { text = "Press |cffffd100Do it for me|r: the test bar's |cffffd100Colour style|r is set to Neon. |cffffd100Expect:|r the bar turns brighter and stronger in the same colour family (a bar with no type stays the fixed blue: styles change type colours only).",
      setup = function() local ns = NS(); if T.cue and ns then ns.BarCueSettings(T.cue.visual).style = "neon"; pcall(ns.RefreshVisual, T.cue); ns.MarkDirty() end end,
      check = function()
          local ns, fr = NS(), Frame()
          if not (fr and fr.barF) then return false, "no test bar (step 1)" end
          local st = ns.BarCueStyle(T.cue)
          if st ~= "neon" then return false, "the cue's style is " .. tostring(st) .. ", not Neon" end
          local r, g, b, _, why, t = ns.BarCueColor(T.cue, nil)
          local dr, dg, db = DrawnColor(fr)
          if not (Near(dr, r, 0.02) and Near(dg, g, 0.02) and Near(db, b, 0.02)) then return false, "the bar was not repainted in the Neon colour" end
          if why == "tooltip" or why == "dispel" then
              local br, bg, bb = ns.BarTypeColor(t, "blizzard")
              if br and Near(br, r, 0.005) and Near(bg, g, 0.005) and Near(bb, b, 0.005) then return false, "Neon gives the same colour as Blizzard default" end
              return true, "Neon " .. tostring(t) .. " drawn"
          end
          return true, "no type colour on this aura: the fixed blue is kept (styles change type colours only)"
      end },
    { text = "Press |cffffd100Do it for me|r: a test group, \"" .. GROUP_NAME .. "\", takes the test rule and forces |cffffd100Muted / Dark|r on every bar in it (the group's Display tab > Every bar: colour style > Force). "
        .. "|cffffd100Expect:|r the bar turns duller and darker; on the bar's own Colour section the style is greyed out and names the group.",
      setup = function()
          local ns = NS()
          if not (T.rule and ns.NewFolder) then return end
          T.group = T.group or ns.NewFolder(GROUP_NAME)
          T.group.barStyle, T.group.barStyleForce = "muted", true
          T.rule.folder = T.group.id
          if ns.SyncCueFolders then ns.SyncCueFolders() end
          pcall(ns.RefreshVisual, T.cue); ns.MarkDirty()
      end,
      check = function()
          local ns = NS()
          if not (T.cue and T.group) then return false, "press Do it for me first" end
          local st, _, gf = ns.BarCueStyle(T.cue)
          if gf ~= T.group then return false, "the group does not force its style on the bar" end
          if st ~= "muted" then return false, "forced style is " .. tostring(st) end
          if ns.BarCueSettings(T.cue.visual).style ~= "neon" then return false, "the bar's own style was overwritten (it should stay Neon underneath)" end
          return true, "the group forces Muted / Dark; the bar's own Neon is kept underneath"
      end },
    { text = "Open the test bar's |cffffd100Bar texture|r list. |cffffd100Expect:|r Flat, Blizzard and Raid frame once each, a run of |cffffd100Blizzard power: ...|r entries (the game's own bar art), the textures your other addons share, \"Texture ID / path...\". No entry twice, no \"XayaUI: ...\" entries (planned, not live).",
      check = function()
          local ns = NS()
          local vals, ord = ns.BarTextureList()
          local seen, dup, power, xaya = {}, nil, 0, 0
          for _, k in ipairs(ord) do
              local l = vals[k]
              if seen[l] then dup = l end
              seen[l] = true
              if tostring(l):find("^Blizzard power: ") then power = power + 1 end
              if tostring(l):find("^XayaUI: ") then xaya = xaya + 1 end
          end
          if dup then return false, "listed twice: " .. tostring(dup) end
          if xaya > 0 then return false, "XayaUI's own fills are listed (they are a roadmap feature)" end
          if power == 0 then return false, "no Blizzard power-bar art found (the game's PowerBarColor list was not readable)" end
          return true, (#ord .. " textures, " .. power .. " Blizzard power art, no duplicates")
      end },
    { text = "In combat (the game decides what addons may read there, so only you can judge this): press |cffffd100Do it for me|r to end the preview, take the test rule out of the group, then get the buff (" .. "the one named on the bar" .. ") and fight a training dummy. Type |cffffd100/xuiengine|r. "
        .. "|cffffd100Expect:|r /xuiengine lists the test rule as drawn by the engine; in combat the bar keeps draining exactly with the buff, with its icon, name and time. Answer Pass or Fail (add a note if it froze or stayed empty).",
      noVerdict = true,
      setup = function()
          local ns = NS()
          if T.cue and ns.SetPreview then ns.SetPreview({ T.cue }, "visual", false) end
          if T.rule then T.rule.folder = nil; if ns.SyncCueFolders then ns.SyncCueFolders() end end
          if ns.AuraDisplay and ns.AuraDisplay.Build then pcall(ns.AuraDisplay.Build) end
          ns.MarkDirty()
      end,
      check = function()
          local ns = NS()
          if not T.cue then return false, "no test bar (step 1)" end
          if not (T.buff and T.buff > 0) then return false, "no buff was found at step 1: the engine has no aura to draw" end
          local owns = ns.EngineOwns and ns.EngineOwns(T.cue)
          return owns and true or false, owns and "the combat engine draws this bar" or "the combat engine does not draw this bar (see /xuiengine for the reason)"
      end },
    { text = "Hover a spell whose tooltip says \"... fire damage ...\" (for example on your action bars or in the spellbook), and a buff of yours that says \"Magic\" at the top right. "
        .. "|cffffd100Expect:|r \"Fire Damage\" in the game's Fire colour (orange), \"Magic\" in blue (Bonus Features > Enhanced Tooltips > Type colours; English game text only).",
      check = function()
          local ns = NS()
          -- (XayaUI_Bonus is reached only through its service: Modules.lua ns.Service; Bonus Tooltips.lua provides "tooltipsDebug")
          local sv = ns and ns.Service and ns.Service("tooltipsDebug")
          local TT = sv and sv.TT
          if not (TT and TT.SectionOn) then return false, "XayaUI Bonus Features (Enhanced Tooltips) is not loaded" end
          if not TT.SectionOn("typeColors") then return false, "Type colours is switched off (or Enhanced Tooltips is off)" end
          local s = ns.BarColorizeTypes and ns.BarColorizeTypes("Deals 10 fire damage.")
          if not (s and s:find("|cff", 1, true) and s:find("Fire Damage", 1, true)) then return false, "the colouring does not work on a sample line" end
          return true, "Type colours is on and colours a sample line"
      end },
    { text = "Last step: press |cffffd100Do it for me|r to remove the test rule, its Bar cue and the test group. Nothing else was changed.",
      setup = RemoveAll,
      check = function()
          local ns = NS()
          for _, r in ipairs(ns.rules or {}) do if r.name == RULE_NAME then return false, "the test rule is still there" end end
          for _, f in ipairs(ns.folders or {}) do if f.name == GROUP_NAME then return false, "the test group is still there" end end
          return true, "removed"
      end },
}

QA.Register("bars-cues", { title = "Bar cues (progress bars)", area = "Bar cues", qa = "B200", order = 240, prefill = true, steps = steps })
QA.BarsTest = T   -- (tests)
