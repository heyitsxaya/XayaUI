#!/usr/bin/env python3
"""In-game QA walkthrough for debug batch W2 (XayaUI_DevAssist 0.7.63, XayaUI_DevAssist/QAWalks-debug-w2.lua; QA B284-B286, J34;
issues #461, #462). Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have
an in game qa test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game (tests/harness), runs each step as a player would (Do it for me,
then the check), and checks:
  - registered with pre-fill, the last step a Done step;
  - step 1: a Bar test rule on a buff with no type is drawn in the fixed blue per style; the note keeps the drawn colours; Pass;
    negative: a style that leaves the blue as it is gives Fail;
  - steps 2-3: the settings window open on the test rule's editor, then the Bar cue walkthrough's own clean-up: Pass, no row left;
    negative: the editor left on another rule's row gives Fail;
  - step 4: no macro hovered yet: not tested (nil); a macro of a fire spell hovered: Pass, the note has the resolved spell ID and
    "Fire Damage <colour>"; negative: a macro whose spell does not match the tooltip: Fail;
  - step 5: the spec count per class from C_SpecializationInfo: Pass; negative: without it, Fail.
Colour numbers and IDs are test stand-ins, not Blizzard's.
Run: python3 tests/qa_walks_debug_w2_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
COMBATLOG_DEFAULT_COLORS = { schoolColoring = {} }
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
COMBATLOG_DEFAULT_COLORS.schoolColoring[Enum.Damageclass.MaskFire] = { r = 0.9, g = 0.4, b = 0.1 }
local def = QA and QA.walks["debug-w2"]
check("the W2 walkthrough is registered with pre-fill, for B284-B286 and J34", def ~= nil and def.prefill == true and def.qa == "B284, B285, B286, J34")
if not def then return R end
check("its last step is a Done step with no verdict", def.steps[#def.steps].done == true and def.steps[#def.steps].noVerdict == true)
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.05, 4); return st.check() end
-- a buff you have now whose tooltip names no type (stand-in)
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraDataByIndex = function(unit, i, f) if i == 1 then return { spellId = 203819, name = "Demon Spikes" } end end
C_TooltipInfo = C_TooltipInfo or {}
C_TooltipInfo.GetSpellByID = function() return { lines = { { leftText = "Demon Spikes" }, { leftText = "Increases your armor." } } } end
local nRules0 = #ns.rules

-- 1 (B284)
local ok1, n1 = run(1)
check("step 1: the fixed blue in each style: Pass", ok1 == true, n1)
check("...the note keeps the drawn colours per style (Neon not the plain blue)", tostring(n1):find("Blizzard default 0.25 0.62 1.00", 1, true) ~= nil and tostring(n1):find("Neon ", 1, true) ~= nil
  and not tostring(n1):find("Neon 0.25 0.62 1.00", 1, true) and not tostring(n1):find("WRONG", 1, true), n1)
local fr = ns.DisplayFrame(QA.BarsTest.cue)
check("...the bar is left in Neon, drawn as the fixed blue in Neon", (function() local r, g, b = ns.BarFallbackColor("neon"); return fr and math.abs(fr.barCR - r) < 0.01 and math.abs(fr.barCG - g) < 0.01 and math.abs(fr.barCB - b) < 0.01 end)())
local realT = ns.BarStyleTransform
ns.BarStyleTransform = function(st, r, g, b) return r, g, b end
local okN = def.steps[1].check()
check("negative: styles that leave the fixed blue as it is give Fail", okN == false)
ns.BarStyleTransform = realT

-- 2, 3 (B285)
local ok2, n2 = run(2); W.tick(0.05, 6); ok2, n2 = def.steps[2].check()
check("step 2: the settings window shows the test rule in the sidebar (its editor open): Pass", ok2 == true, n2)
local ok3, n3 = run(3); W.tick(0.05, 6); ok3, n3 = def.steps[3].check()
check("step 3: the Bar cue walkthrough's clean-up: gone from the data, the sidebar and the editor: Pass", ok3 == true, n3)
check("...no sidebar row shows it (read from the open window)", QA.WindowMentions("XayaUI QA: Bar test") == 0)
check("...nothing left behind", #ns.rules == nRules0, #ns.rules .. "/" .. nRules0)
QA.BarsTest.shifted = 3
check("negative: the editor left on another rule's row gives Fail", def.steps[3].check() == false)
QA.BarsTest.shifted = nil

-- 4 (B286)
local sv = ns.Service("tooltipsDebug"); local TT = sv and sv.TT
TT.lastMacro = nil
local ok4, n4 = def.steps[4].check()
check("step 4 before any macro was hovered: not tested (nil)", ok4 == nil, n4)
rawset(_G, "GetMacroSpell", function(m) if m == 7 then return 204596 end end)
local realName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) if id == 204596 then return "Sigil of Flame" end return realName and realName(id) end
local function hover(title, body, id)
  local L1, L2 = { v = title }, { v = body }
  local function fs(t) return { GetText = function() return t.v end, SetText = function(_, x) t.v = x end } end
  _G.XUIW2TipTextLeft1, _G.XUIW2TipTextLeft2 = fs(L1), fs(L2)
  local tip = { GetName = function() return "XUIW2Tip" end, NumLines = function() return 2 end, AddLine = function() end, AddDoubleLine = function() end }
  for _, p in ipairs(W.tooltipPostCalls or {}) do if p[1] == Enum.TooltipDataType.Macro then p[2](tip, { id = id, lines = { { leftText = title }, { leftText = body } } }) end end
  return L2.v
end
local line = hover("Sigil of Flame", "Deals 120 fire damage.", 7)
ok4, n4 = def.steps[4].check()
check("step 4: a macro of a fire spell hovered: Pass, with the resolved spell ID and the coloured word in the note",
  ok4 == true and tostring(n4):find("spell 204596", 1, true) ~= nil and tostring(n4):find("Fire Damage e6661a", 1, true) ~= nil, n4)
check("...the hovered line itself is coloured", line == "Deals 120 |cffe6661aFire Damage|r.", line)
hover("Infernal Strike", "Deals 60 fire damage.", 7)
local okM, nM = def.steps[4].check()
check("negative: a macro whose spell does not match the tooltip (no spell resolved): Fail, the reason in the note", okM == false and tostring(nM):find("not the spell's name", 1, true) ~= nil, nM)
C_Spell.GetSpellName = realName; rawset(_G, "GetMacroSpell", nil)

-- 5 (J34)
local ok5, n5 = def.steps[5].check()
check("step 5: the spec count per class from C_SpecializationInfo: Pass, the counts in the note", ok5 == true and tostring(n5):find("12=", 1, true) ~= nil, n5)
local realCSI = C_SpecializationInfo
C_SpecializationInfo = nil
check("negative: without C_SpecializationInfo.GetNumSpecializationsForClassID: Fail", def.steps[5].check() == false)
C_SpecializationInfo = realCSI
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
