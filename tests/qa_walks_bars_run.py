#!/usr/bin/env python3
"""In-game QA walkthrough for Bar cues (XayaUI_DevAssist 0.7.14, XayaUI_DevAssist/QAWalks-bars.lua; REQUEST-LOG A11).
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
-- 4 (Dev Assist 0.7.53, #461): first with NO type on the aura: Neon cannot change the fixed blue, so the drawn colour equals Blizzard
-- default and the check must say Fail ("no style changed the bar"); before, it returned Pass without testing anything
C_TooltipInfo = C_TooltipInfo or {}
C_TooltipInfo.GetSpellByID = function() return { lines = { { leftText = "Demon Spikes" }, { leftText = "Increases your armor." } } } end
ns.BarForgetTooltipTypes()
do
  -- (Dev Assist 0.7.63 / Rules 0.6.79, #461 "Style the fixed blue too") Neon now changes the fixed blue: Pass, and the drawn colour
  -- is the blue in Neon (on 0.7.62 / Rules 0.6.78 this said Fail: "no style changed the bar")
  local st4 = step(4); st4.setup(); W.tick(0.05, 3)
  local okN, nN = st4.check()
  local dr, dg, db = fr.barCR, fr.barCG, fr.barCB
  local nr, ng, nb = ns.BarStyleTransform("neon", 0.25, 0.62, 1)
  check("step 4 with no type on the aura: Pass, the fixed blue is drawn in Neon (not the plain blue)", okN == true and tostring(nN):find("fixed blue", 1, true) ~= nil
    and math.abs(dr - nr) < 0.01 and math.abs(dg - ng) < 0.01 and math.abs(db - nb) < 0.01 and not (math.abs(dr - 0.25) < 0.01 and math.abs(dg - 0.62) < 0.01),
    tostring(okN) .. " " .. tostring(nN) .. (" drawn %.2f %.2f %.2f"):format(dr or -1, dg or -1, db or -1))
  local realT = ns.BarStyleTransform
  ns.BarStyleTransform = function(style, r, g, b) return r, g, b end
  fr.barCR = nil; ns.UpdateVisualText(T.cue, nil)
  local okU, nU = st4.check()
  check("negative: no type and a style that leaves the fixed blue as it is: Fail (drawn = Blizzard default)", okU == false and tostring(nU):find("no style changed the bar", 1, true) ~= nil, tostring(okU) .. " " .. tostring(nU))
  ns.BarStyleTransform = realT
  ns.BarCueSettings(T.cue.visual).style = "blizzard"; pcall(ns.RefreshVisual, T.cue)
end
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
local okT, nT = chk(4)
check("negative: a style that changes nothing gives Fail (drawn = Blizzard default)", okT == false and tostring(nT):find("no style changed the bar", 1, true) ~= nil, tostring(okT) .. " " .. tostring(nT))
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
-- 8 (Dev Assist 0.7.53, #461): a question for her (the addon cannot read the tooltip she hovered; coloring its own sample line tested
-- nothing she sees); the check only reports the switch
check("step 8 is a question for the person (noVerdict), with no sample-line test", def.steps[8].noVerdict == true)
local ok8, n8 = chk(8); check("step 8: reports Type colours switched on", ok8 and not tostring(n8):find("sample", 1, true), n8)
ns.TT.DB().typeColors.enabled = false
check("negative: Type colours off gives Fail", not chk(8))
ns.TT.DB().typeColors.enabled = true
-- 9 (Dev Assist 0.7.53, #461): what she sees: gone from the data AND from the Rules sidebar rows and the editor of the open window
check("step 9 is a clean-up step (Done, no verdict)", def.steps[9].done == true)
local ok9c, n9c = chk(9)
check("step 9 before the clean-up: Fail (the rule is still there)", ok9c == false, n9c)
pcall(ns.LoadOptions); W.tick(0.05, 2)
local ACD = LibStub("AceConfigDialog-3.0")
if not (ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6)
ACD = LibStub("AceConfigDialog-3.0")
pcall(ACD.SelectGroup, ACD, "CueRules", "cooldowns"); W.tick(0.05, 4)
local rows0 = QA.WindowMentions("XayaUI QA: Bar test")
check("(the settings window is open and its sidebar lists the test rule before the clean-up)", rows0 ~= nil and rows0 > 0, rows0)
-- (Dev Assist 0.7.63, #461) her case: the test rule's editor is open (Cues tab) and one of her rules comes after it in the list. Rows are
-- keyed by place ("rule" .. i): before 0.7.63 the clean-up left the selection on that place, so the editor slid onto her next rule.
local later = ns.NewRule(); later.name = "Her later rule"; later.enabled = true; ns.NormalizeRule(later); ns.rules[#ns.rules + 1] = later
pcall(ns.MarkDirty); local od = ns.Service("optionsDebug"); if od and od.Notify then od.Notify() end; W.tick(0.05, 4)
local okx, ctx = pcall(ns.ReadContext)
local tpath = { ns.ScopePath(T.rule, okx and ctx or nil) }; tpath[#tpath + 1] = "cues"
pcall(ACD.SelectGroup, ACD, "CueRules", unpack(tpath)); W.tick(0.05, 6)
local tIdx; for i, r in ipairs(ns.rules) do if r == T.rule then tIdx = i end end
local function SelIdx() local S = ns.RulesTreeStatus(); return S and S.selected and tonumber(S.selected:match("rule(%d+)$")) end
check("(the test rule's editor is open: its row is selected)", tIdx ~= nil and SelIdx() == tIdx, tostring(SelIdx()) .. " vs " .. tostring(tIdx))
local ok9, n9 = run(9); W.tick(0.05, 6); ok9, n9 = chk(9)
check("step 9: the test rule, its cue and the test group are gone from the data, the sidebar and the editor: Pass", ok9 == true, n9)
local rowsAfter = QA.WindowMentions("XayaUI QA: Bar test")
check("step 9: no sidebar row shows the test rule after the clean-up (read from the open window)", rowsAfter == 0, rowsAfter)
local sAfter = SelIdx()
check("step 9: the editor did not slide onto her next rule: no rule row at the test rule's old place or after is selected (back to the list, as Delete this rule does)",
  not (sAfter and sAfter >= tIdx), tostring(sAfter))
for i = #ns.rules, 1, -1 do if ns.rules[i] == later then table.remove(ns.rules, i) end end
check("...nothing else was added or left behind", #ns.rules == nRules0 and #ns.folders == nFolders0, #ns.rules .. "/" .. nRules0 .. " " .. #ns.folders .. "/" .. nFolders0)
-- negative: a clean-up that left the editor on a moved row gives Fail
T.shifted = 5
local okSh, nSh = chk(9)
check("negative: the editor left on another rule's row gives Fail", okSh == false and tostring(nSh):find("another rule", 1, true) ~= nil, tostring(okSh) .. " " .. tostring(nSh))
T.shifted = nil
-- negative: the data is gone but a sidebar row still shows the name (a window that was not redrawn): Fail
local function AnyRow()
  local root = ACD.OpenFrames and ACD.OpenFrames.CueRules
  local found
  local function walk(w) if found or type(w) ~= "table" then return end
    if w.type == "TreeGroup" and w.buttons then for _, b in ipairs(w.buttons) do if b:IsShown() and b.text then found = b; return end end end
    for _, c in ipairs(w.children or {}) do walk(c) end end
  walk(root); return found
end
local rb = AnyRow()
if rb then
  local was = rb.text:GetText(); rb.text:SetText("XayaUI QA: Bar test")
  local okS, nS = chk(9)
  check("negative: a sidebar row still showing the removed rule gives Fail", okS == false and tostring(nS):find("sidebar row", 1, true) ~= nil, tostring(okS) .. " " .. tostring(nS))
  rb.text:SetText(was)
else
  check("negative: a sidebar row to test with", false, "no sidebar row found")
end
pcall(ns.ToggleUI); W.tick(0.05, 3)
local okC, nC = chk(9)
check("step 9 with the settings window closed: not tested (nil): the rows cannot be read", okC == nil, tostring(okC) .. " " .. tostring(nC))
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
