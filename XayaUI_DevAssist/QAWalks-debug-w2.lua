-------------------------------------------------------------------------------
-- QAWalks-debug-w2.lua (XayaUI_DevAssist 0.7.63): in-game QA walkthrough for debug batch W2 (Rules 0.6.79, Bonus 0.6.36, Dev Assist
-- 0.7.63; QA steps B284 to B286, J34):
--   #461 "Style the fixed blue too" (Xaya 2026-11-07): a bar with no type color is drawn in its color style too (B284);
--   #461 the stale "XayaUI QA: Bar..." sidebar row: the Bar cue walkthrough's clean-up leaves no row and no editor on another rule (B285);
--   #462 macro tooltips: a macro of a fire spell shows "Fire Damage" in the Fire color, with the macro's spell resolved (B286);
--   the Aura catalogue's item-set step reads the spec count from C_SpecializationInfo (J34).
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click);
-- what it reads is written into the step's note. Reuses the Bar cue walkthrough's test rule and clean-up (QAWalks-bars.lua: steps 1
-- and 9, QA.BarsTest), so B285 checks that walkthrough's own clean-up. Reaches XayaUI Rules through ns.*, Enhanced Tooltips through
-- its "tooltipsDebug" service, the settings window through ns.LoadOptions, AceConfigDialog and ns.OptionsApi.RuleEditor.ScopePath
-- (Rules Options 0.6.80). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Bars() return QA.walks and QA.walks["bars-cues"] end
local function T() return QA.BarsTest end
local function Num(v) if type(v) == "number" and not (rawget(_G, "issecretvalue") and issecretvalue(v)) then return v end end
local function Near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= 0.01 end
local RULE_NAME = "XayaUI QA: Bar test"

-- a buff on you whose tooltip names no school or dispel type (the bar then has no type color: the fixed blue), else nil
local function TypelessBuff()
    local ns, CU = NS(), rawget(_G, "C_UnitAuras")
    if not (ns and ns.BarTooltipType and CU and CU.GetAuraDataByIndex) then return nil end
    for i = 1, 40 do
        local ok, a = pcall(CU.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not (ok and type(a) == "table") then break end
        local id = Num(a.spellId)
        local okd, d = pcall(function() return a.dispelName end)
        local disp = okd and type(d) == "string" and not (rawget(_G, "issecretvalue") and issecretvalue(d)) and d ~= "" and d or nil
        if id and id > 0 and not disp then
            local okt, t = pcall(ns.BarTooltipType, id)
            if okt and not t then return id end
        end
    end
end
local function Frame() local ns, t = NS(), T(); return t and t.cue and ns and ns.DisplayFrame and ns.DisplayFrame(t.cue) or nil end
-- the bar's drawn color: the game's own read where it answers, else what XayaUI last painted
local function Drawn(fr)
    local bar = fr and fr.barF
    if not bar then return nil end
    if bar.GetStatusBarColor then
        local ok, r, g, b = pcall(bar.GetStatusBarColor, bar)
        if ok and Num(r) and Num(g) and Num(b) then return r, g, b end
    end
    return fr.barCR, fr.barCG, fr.barCB
end
local function Paint(style)
    local ns, t = NS(), T()
    ns.BarCueSettings(t.cue.visual).style = style
    pcall(ns.RefreshVisual, t.cue)
    local fr = Frame()
    if fr then fr.barCR = nil; pcall(ns.UpdateVisualText, t.cue, nil) end
    return Drawn(fr)
end

-- B284 (#461): the fixed blue in each style
local function SetupBlue()
    local ns, w = NS(), Bars()
    if not (ns and ns.BarCueSettings and w) then return end
    if not (T() and T().rule) then w.steps[1].setup() end
    local t = T()
    if not (t and t.rule) then return end
    t.rule.buffID = TypelessBuff() or 0   -- (0: no buff with no type found: the preview bar alone, which has no type either)
    t.buff = t.rule.buffID
    if ns.BarForgetTooltipTypes then ns.BarForgetTooltipTypes() end
    Paint("neon")
    if ns.MarkDirty then ns.MarkDirty() end
end
local function CheckBlue()
    local ns, t = NS(), T()
    if not (ns and ns.BarFallbackColor) then return false, "XayaUI Rules is older than 0.6.79 (no styled fixed blue)" end
    if not (t and t.cue and Frame()) then return nil, "press Do it for me first" end
    local _, _, _, _, why, ty = ns.BarCueColor(t.cue, nil)
    if why ~= "fallback" then return nil, "this bar has a type color (" .. tostring(ty) .. "), not the fixed blue: press Do it for me again with no buff of that kind, or use the preview" end
    local out, ok = {}, true
    for _, st in ipairs({ "blizzard", "neon", "pastel", "muted", "custom" }) do
        local r, g, b = Paint(st)
        local er, eg, eb = ns.BarFallbackColor(st)
        local plain = Near(r, 0.25) and Near(g, 0.62) and Near(b, 1)
        local good = Near(r, er) and Near(g, eg) and Near(b, eb) and ((st == "blizzard" or st == "custom") == plain)
        if not good then ok = false end
        out[#out + 1] = ("%s %.2f %.2f %.2f%s"):format(ns.BAR_STYLE_LABEL[st] or st, r or -1, g or -1, b or -1, good and "" or " (WRONG)")
    end
    Paint("neon")
    return ok, "drawn fixed blue per style: " .. table.concat(out, "; ") .. " (buff " .. tostring(t.buff) .. ")"
end

-- B285 (#461): the Bar cue walkthrough's clean-up, with the test rule's editor open (her case)
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function SetupOpenEditor()
    local ns, t = NS(), T()
    if not (t and t.rule and ns and ns.LoadOptions and ns.LoadOptions()) then return end
    local a = ACD(); if not a then return end
    local root = a.OpenFrames and a.OpenFrames["CueRules"]
    if not (root and root.frame and root.frame:IsShown()) then a:Open("CueRules") end
    local okc, ctx = pcall(ns.ReadContext)
    local RE = ns.OptionsApi and ns.OptionsApi.RuleEditor
    local scope = RE and RE.ScopePath   -- (XayaUI Rules Options 0.6.80 publishes it for this walkthrough)
    if not scope then return end
    local path = { scope(t.rule, okc and ctx or nil) }
    path[#path + 1] = "cues"
    pcall(a.SelectGroup, a, "CueRules", unpack(path))
end
local function CheckOpenEditor()
    local t = T()
    if not (t and t.rule) then return nil, "no test rule: go back to step 1 and press Do it for me" end
    local rows = QA.WindowMentions and QA.WindowMentions(RULE_NAME)
    if rows == nil then return nil, "the settings window is not open: press Do it for me" end
    return rows > 0, ("the Rules sidebar shows the test rule in %d row(s)"):format(rows)
end
local function SetupCleanup() local w = Bars(); if w and w.steps[9] and w.steps[9].setup then w.steps[9].setup() end end
local function CheckCleanup()
    local w = Bars()
    if not (w and w.steps[9]) then return false, "the Bar cue walkthrough is not loaded" end
    local ok, note = w.steps[9].check()
    local t = T() or {}
    return ok, tostring(note) .. (t.leftEditor and "; the editor went back to the list" or "")
end

-- B286 (#462): a macro of a fire spell, hovered
local function CheckMacro()
    local ns = NS()
    local sv = ns and ns.Service and ns.Service("tooltipsDebug")
    local TT = sv and sv.TT
    if not (TT and TT.SectionOn) then return false, "XayaUI Bonus Features (Enhanced Tooltips) is not loaded" end
    if not TT.OnMacroData then return false, "XayaUI Bonus Features is older than 0.6.36 (no macro tooltips)" end
    if not TT.SectionOn("typeColors") then return false, "Type colors is switched off (Bonus Features > Tooltips)" end
    local m = TT.lastMacro
    if not m then return nil, "no macro tooltip seen since /reload: hover the macro on your action bar, then press Check" end
    local words = (type(m.colored) == "table" and #m.colored > 0) and table.concat(m.colored, ", ") or "none"
    local note = ("macro %s -> spell %s%s; colored words: %s"):format(tostring(m.macroID), tostring(m.spellID),
        m.spellID and "" or (" (" .. tostring(m.why) .. ")"), words)
    return (m.spellID ~= nil and words ~= "none"), note
end

-- J34: the catalogue's item-set step
local function CheckSpecCount()
    local CSI = rawget(_G, "C_SpecializationInfo")
    local fn = CSI and CSI.GetNumSpecializationsForClassID
    if type(fn) ~= "function" then return false, "the game has no C_SpecializationInfo.GetNumSpecializationsForClassID" end
    local parts, ok = {}, true
    for cid = 1, 13 do
        local okc, n = pcall(fn, cid)
        local v = okc and Num(n)
        if not v then ok = false end
        parts[#parts + 1] = cid .. "=" .. tostring(v or "?")
    end
    local old = rawget(_G, "GetNumSpecializationsForClassID")
    return ok, "spec count per class ID (what the catalogue's item-set step now reads): " .. table.concat(parts, ", ")
        .. "; the old global GetNumSpecializationsForClassID: " .. (type(old) == "function" and "present" or "absent")
end

QA.Register("debug-w2", { title = "Bar colors and tooltips: the fixed blue in color styles, the Bar test clean-up, macro tooltips (B284-B286, J34, debug W2)",
    qa = "B284, B285, B286, J34", order = 515, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the Bar cue walkthrough's test rule (\"" .. RULE_NAME .. "\") is made on a buff of yours whose tooltip names no type (or, with none, as a preview), so the bar has no type color: the fixed blue. Its |cffffd100Color style|r is set to Neon.\n\n|cffffd100Expect:|r the bar is a stronger, brighter blue than the plain fixed blue. The check paints the bar in each style and writes the drawn colors into the note: Blizzard default and Custom keep the plain blue (0.25 0.62 1.00); Neon, Pastel and Muted / Dark each change it.",
        setup = SetupBlue, check = CheckBlue },
    { text = "Press |cffffd100Do it for me|r: the settings window opens on the test rule's |cffffd100Cues|r tab, the way it was open when you saw the stale row.\n\n|cffffd100Expect:|r the Rules sidebar shows \"" .. RULE_NAME .. "\" and its editor is open.",
        setup = SetupOpenEditor, check = CheckOpenEditor },
    { text = "Press |cffffd100Do it for me|r: the Bar cue walkthrough's own clean-up removes the test rule, its Bar cue and test group, with the window still open.\n\n|cffffd100Expect:|r no \"XayaUI QA: Bar...\" row is left in the sidebar, and the editor goes back to the list (it does not open another of your rules in its place).",
        setup = SetupCleanup, check = CheckCleanup },
    { text = "Put a macro that casts a fire spell on your action bar (for example your Sigil of Flame or Infernal Strike macro) and hover it, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the tooltip shows \"Fire Damage\" in the game's Fire color (orange), and Spell ID / Cooldown lines as on the spell itself. The note keeps the macro's resolved spell ID and the colored words read from the tooltip.",
        check = CheckMacro },
    { text = "Press |cffffd100Check|r: the addon reads the game's spec count per class, which the Aura catalogue's item-set step (/xuidev catalogue) now uses.\n\n|cffffd100Expect:|r a number for every class (Demon Hunter 12 = 3).",
        check = CheckSpecCount },
    { done = true, noVerdict = true, text = "Last step: anything look wrong (a color, a leftover row, a tooltip line)? Write it in the note, then press |cffffd100Done|r (no verdict: a note is kept, nothing is recorded as Pass or Fail)." },
} })
