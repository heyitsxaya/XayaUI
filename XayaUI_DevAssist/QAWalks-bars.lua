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
-- (Dev Assist 0.7.53, issue #461) step 4 compares the drawn colour with the same bar in Blizzard default and fails when they are equal
-- (a bar with no type colour can no longer pass); step 8 is a question for her (the addon cannot read the tooltip she hovered); step 9
-- is a clean-up (Done) step whose check reads the open settings window: no Rules sidebar row and nothing in the editor shows the rule.
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

-- (0.7.53) where the open settings window shows a text: sidebar rows (the Rules tree) and anything else drawn (the editor); nil, nil
-- when the window is closed. Shared: QA.WindowMentions(text).
function QA.WindowMentions(text)
    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    local root = ACD and ACD.OpenFrames and ACD.OpenFrames["CueRules"]
    if not root then return nil, nil end
    local function Txt(o)
        if not (o and o.GetText) then return nil end
        local ok, t = pcall(o.GetText, o)
        return (ok and type(t) == "string") and t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or nil
    end
    local function Vis(f) if not (f and f.IsVisible) then return true end local ok, v = pcall(f.IsVisible, f); return ok and v and true or false end
    local rows, editor, seen = 0, 0, {}
    local function walk(w, d)
        if type(w) ~= "table" or d > 40 or seen[w] then return end
        seen[w] = true
        if w.type == "TreeGroup" and type(w.buttons) == "table" then
            for _, b in ipairs(w.buttons) do
                local t = Txt(b.text)
                if b.IsShown and b:IsShown() and t and t:find(text, 1, true) then rows = rows + 1 end
            end
        elseif Vis(w.frame) then
            for _, k in ipairs({ "label", "text", "editbox" }) do
                local t = Txt(w[k]); if t and t:find(text, 1, true) then editor = editor + 1; break end
            end
        end
        for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
    end
    walk(root, 0)
    return rows, editor
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
    { text = "Look at the bar's color. Open the test rule's Cues tab (Rules list) > Bar Options > Color: the |cffffd100Now:|r line says which color it uses and why (the type the tooltip names, e.g. \"Fire Damage\", else the aura's dispel type, else blue). "
        .. "|cffffd100Expect:|r the bar has that color.",
      check = function()
          local ns, fr = NS(), Frame()
          if not (fr and fr.barF) then return false, "no test bar (step 1)" end
          local r, g, b, _, why, t = ns.BarCueColor(T.cue, nil)
          local dr, dg, db = DrawnColor(fr)
          if not (Near(dr, r, 0.02) and Near(dg, g, 0.02) and Near(db, b, 0.02)) then return false, "the bar is not drawn in the color XayaUI chose" end
          local what = (why == "tooltip" and ("named in the tooltip: " .. tostring(t))) or (why == "dispel" and ("the aura's dispel type: " .. tostring(t))) or (why == "fixed" and "a fixed color") or "no type found: the fixed blue"
          return true, "drawn in the chosen color (" .. what .. ")"
      end },
    { text = "Press |cffffd100Do it for me|r: the test bar's |cffffd100Color style|r is set to Neon. |cffffd100Expect:|r the bar turns brighter and stronger in the same color family (a bar with no type stays the fixed blue: styles change type colors only).",
      setup = function() local ns = NS(); if T.cue and ns then ns.BarCueSettings(T.cue.visual).style = "neon"; pcall(ns.RefreshVisual, T.cue); ns.MarkDirty() end end,
      check = function()
          local ns, fr = NS(), Frame()
          if not (fr and fr.barF) then return false, "no test bar (step 1)" end
          local st = ns.BarCueStyle(T.cue)
          if st ~= "neon" then return false, "the cue's style is " .. tostring(st) .. ", not Neon" end
          local r, g, b, _, why, t = ns.BarCueColor(T.cue, nil)
          local dr, dg, db = DrawnColor(fr)
          if not (Near(dr, r, 0.02) and Near(dg, g, 0.02) and Near(db, b, 0.02)) then return false, "the bar was not repainted in the Neon color" end
          -- (0.7.53, #461) the same bar in Blizzard default: its type's own color, or (no type, a fixed color) the color it already has.
          -- A drawn color equal to that means no style changed the bar, whatever the reason: Fail, never a Pass by default.
          local br, bg, bb
          if why == "tooltip" or why == "dispel" then br, bg, bb = ns.BarTypeColor(t, "blizzard") else br, bg, bb = r, g, b end
          local drawn = ("%.2f %.2f %.2f"):format(dr or 0, dg or 0, db or 0)
          if not br then return false, "Blizzard default has no color for " .. tostring(t) .. ": nothing to compare the Neon bar with" end
          if Near(br, dr, 0.005) and Near(bg, dg, 0.005) and Near(bb, db, 0.005) then
              return false, ("no style changed the bar: drawn %s, the same as Blizzard default (%s)"):format(drawn,
                  (why == "tooltip" or why == "dispel") and ("type " .. tostring(t)) or "this aura has no type color, so the bar keeps its fixed color")
          end
          return true, ("Neon %s drawn %s; Blizzard default %.2f %.2f %.2f"):format(tostring(t), drawn, br, bg, bb)
      end },
    { text = "Press |cffffd100Do it for me|r: a test group, \"" .. GROUP_NAME .. "\", takes the test rule and forces |cffffd100Muted / Dark|r on every bar in it (the group's Display tab > Every bar: color style > Force). "
        .. "|cffffd100Expect:|r the bar turns duller and darker; on the bar's own Color section the style is greyed out and names the group.",
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
        .. "|cffffd100Expect:|r \"Fire Damage\" in the game's Fire color (orange), \"Magic\" in blue (Bonus Features > Enhanced Tooltips > Type colors; English game text only). |cffffd100Your call:|r Pass if both show in those colors; Fail and say what you saw.",
      -- (0.7.53, #461) the addon cannot read the tooltip you hovered (it is gone once you move to this window), and coloring a sample
      -- line of its own tests nothing you see: this is your call; the check only reports whether Type colors is switched on
      noVerdict = true,
      check = function()
          local ns = NS()
          -- (XayaUI_Bonus is reached only through its service: Modules.lua ns.Service; Bonus Tooltips.lua provides "tooltipsDebug")
          local sv = ns and ns.Service and ns.Service("tooltipsDebug")
          local TT = sv and sv.TT
          if not (TT and TT.SectionOn) then return false, "XayaUI Bonus Features (Enhanced Tooltips) is not loaded" end
          if not TT.SectionOn("typeColors") then return false, "Type colors is switched off (or Enhanced Tooltips is off)" end
          return true, "Type colors is switched on; the colors in the tooltip you hovered are yours to judge"
      end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to remove the test rule, its Bar cue and the test group. Nothing else was changed. Then press |cffffd100Done|r.",
      setup = function()
          RemoveAll()
          -- the settings window (if open) is redrawn, so its Rules sidebar and editor show the rules as they are now
          local ns = NS(); local od = ns and ns.Service and ns.Service("optionsDebug")
          if od and od.Notify then pcall(od.Notify) end
      end,
      -- (0.7.53, #461) what you see, not only the data: the rule and group are gone from XayaUI's lists AND no row of the Rules sidebar
      -- and nothing in the editor shows the test rule's name (read from the open settings window)
      check = function()
          local ns = NS()
          for _, r in ipairs(ns.rules or {}) do if r.name == RULE_NAME then return false, "the test rule is still in your rules" end end
          for _, f in ipairs(ns.folders or {}) do if f.name == GROUP_NAME then return false, "the test group is still there" end end
          local rows, editor = QA.WindowMentions(RULE_NAME)
          if rows == nil then return nil, "gone from your rules; open the settings window (/xui) on the Rules tab and press Check again: the sidebar rows are read from it" end
          if rows > 0 or editor > 0 then
              return false, ("gone from your rules, but the settings window still shows it: %d sidebar row(s), %d place(s) in the editor"):format(rows, editor)
          end
          return true, "removed: not in your rules, no sidebar row and nothing in the editor shows it"
      end },
}

QA.Register("bars-cues", { title = "Bar cues: progress bars that show how much time a buff has left", area = "Bar cues", qa = "B200", order = 240, prefill = true, steps = steps })
QA.BarsTest = T   -- (tests)
