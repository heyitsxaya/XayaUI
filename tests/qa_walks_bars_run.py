#!/usr/bin/env python3
"""In-game QA walkthrough for Bar cues (XayaUI_DevAssist 0.7.13, XayaUI_DevAssist/QAWalks-bars.lua; REQUEST-LOG A11).
Xaya's rule (relayed 2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa
test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game (tests/harness), runs every step of the walkthrough as a player
would ("Do it for me", then the check), and checks:
  - it is registered with pre-fill, and the combat step is a question for the person (noVerdict);
  - each step's check gives Pass on the working Bar cue code;
  - negative controls (V1): the same checks give Fail when the behaviour is broken (a wrong background, a bar that does not move, a bar
    drawn in another colour than XayaUI chose, a style that does not change the colour, a group that does not force, a texture listed
    twice, Type colours off);
  - the last step removes the test rule, its cue and the test group.
Run: python3 tests/qa_walks_bars_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
check("XayaUI Dev Assist's walkthrough framework is loaded", QA ~= nil)
if not QA then return R end
local def = QA.walks["bars-cues"]
check("the Bar cue walkthrough is registered, with pre-fill, for QA B200", def ~= nil and def.prefill == true and def.qa == "B200")
if not def then return R end
check("its combat step is a question for the person (no automatic verdict)", def.steps[7] and def.steps[7].noVerdict == true)
-- a buff the player has now (the stand-in answers the aura read)
C_UnitAuras = C_UnitAuras or {}
local realByIndex = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, i, f) if i == 1 then return { spellId = 203819, name = "Demon Spikes" } end end
-- the game's power-bar list (test stand-in)
PowerBarColor = { FURY = { atlas = "Test_Fury_Fill" } }
local realCT = C_Texture
C_Texture = setmetatable({ GetAtlasInfo = function(n) return { width = 64, height = 8 } end }, { __index = realCT })   -- (the game knows its atlases)
local T = QA.BarsTest
local function step(i) return def.steps[i] end
local function run(i) local st = step(i); if st.setup then st.setup() end; W.tick(0.05, 3); return st.check() end
local function chk(i) return step(i).check() end
local nRules0, nFolders0 = #ns.rules, #ns.folders

-- 1
local ok1, n1 = run(1); check("step 1: a test Bar rule on a buff you have, previewed: Pass", ok1, n1)
check("...the rule is on the buff that was found (203819)", T.rule and T.rule.buffID == 203819 and T.cue and T.cue.cueKind == "bar")
T.cue.visual.bg.color = { 0, 0, 0, 0.55 }
check("negative: a 55 % background gives Fail", not chk(1))
T.cue.visual.bg.color = { 0, 0, 0, 0.2 }
-- 2
local ok2, n2 = run(2)
W.tick(0.1, 10)
ok2, n2 = chk(2); check("step 2: the preview bar moves: Pass", ok2, n2)
local fr = ns.DisplayFrame(T.cue)
local realGet = fr.barF.GetValue
local frozen = fr.barF:GetValue()
rawset(fr.barF, "GetValue", function() return frozen end)
local realScript = fr:GetScript("OnUpdate")
fr:SetScript("OnUpdate", nil); fr.barTimed = nil
T.v0, T.t0 = frozen, GetTime() - 1
check("negative: a bar that does not move gives Fail", not chk(2))
rawset(fr.barF, "GetValue", nil); fr:SetScript("OnUpdate", realScript)
-- 3
local ok3, n3 = chk(3); check("step 3: drawn in the colour XayaUI chose: Pass", ok3, n3)
local cr = fr.barCR; fr.barCR = (cr or 0) + 0.3
rawset(fr.barF, "GetStatusBarColor", function() return fr.barCR, fr.barCG, fr.barCB, 1 end)
check("negative: a bar drawn in another colour gives Fail", not chk(3))
fr.barCR = cr
-- 4: give the cue a type colour (a tooltip that names Fire) so the style has something to change
TEST_FIRE = { r = 0.9, g = 0.4, b = 0.1 }
COMBATLOG_DEFAULT_COLORS = { schoolColoring = { [Enum.Damageclass.MaskFire] = TEST_FIRE } }
C_TooltipInfo = C_TooltipInfo or {}
C_TooltipInfo.GetSpellByID = function() return { lines = { { leftText = "Demon Spikes" }, { leftText = "Deals 5 Fire damage to attackers." } } } end
ns.BarForgetTooltipTypes()
local ok4, n4 = run(4); W.tick(0.05, 3); ok4, n4 = chk(4)
check("step 4: Neon repaints the bar in a Neon colour: Pass", ok4, n4)
local realTransform = ns.BarStyleTransform
ns.BarStyleTransform = function(style, r, g, b) return r, g, b end
fr.barCR = nil; ns.UpdateVisualText(T.cue, nil)
check("negative: a style that changes nothing gives Fail", not chk(4))
ns.BarStyleTransform = realTransform; fr.barCR = nil; ns.UpdateVisualText(T.cue, nil)
-- 5
local ok5, n5 = run(5); check("step 5: a group forces Muted / Dark, the bar keeps its own Neon underneath: Pass", ok5, n5)
T.group.barStyleForce = nil
check("negative: a group that does not force gives Fail", not chk(5))
T.group.barStyleForce = true
-- 6
local ok6, n6 = chk(6); check("step 6: texture list without duplicates, with the game's power art, no XayaUI fills: Pass", ok6, n6)
local realList = ns.BarTextureList
ns.BarTextureList = function() local v, o = realList(); v.zzdup = v[o[1]]; o[#o + 1] = "zzdup"; return v, o end
check("negative: a texture listed twice gives Fail", not chk(6))
ns.BarTextureList = realList
-- 7 (a question for the person; its check only says whether the engine took the bar)
local ok7, n7 = run(7); check("step 7: preview off, rule out of the group; the check reports what the engine does", n7 ~= nil and T.rule.folder == nil and not ns.IsPreview(T.cue, "visual"), n7)
-- 8
local ok8, n8 = chk(8); check("step 8: Type colours on and working: Pass", ok8, n8)
ns.TT.DB().typeColors.enabled = false
check("negative: Type colours off gives Fail", not chk(8))
ns.TT.DB().typeColors.enabled = true
-- 9
local ok9, n9 = run(9); check("step 9: the test rule, its cue and the test group are removed: Pass", ok9, n9)
check("...nothing else was added or left behind", #ns.rules == nRules0 and #ns.folders == nFolders0, #ns.rules .. "/" .. nRules0 .. " " .. #ns.folders .. "/" .. nFolders0)
C_UnitAuras.GetAuraDataByIndex = realByIndex; PowerBarColor = nil; C_Texture = realCT
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
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
