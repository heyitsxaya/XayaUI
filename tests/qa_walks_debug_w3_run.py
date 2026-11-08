#!/usr/bin/env python3
"""In-game QA walkthrough for debug batch W3 (XayaUI_DevAssist 0.7.64, XayaUI_DevAssist/QAWalks-debug-w3.lua; QA B287-B290; issues
#478, #468, #471, #483). Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes
have an in game qa test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game, runs each step as a player would (Do it for me, then the check):
  - registered with pre-fill, the last step a Done step that puts Advanced customization back;
  - step 1 (#478): the window collapsed by its arrow: Pass, the note has the right edges open / collapsed; negative: the X moved
    beside the title (the old anchor) gives Fail;
  - step 2 (#468): the bottom Close, the arrow and the ? flat: Pass; negative: the Close button's red art showing gives Fail;
  - step 3 (#471): the Theme page: Accept flat, one Reset column inside the boxes, Delete saved inside the margin: Pass; negatives: a
    Reset moved out of line, the Accept's red art showing: Fail;
  - step 4 (#483): before a result click: not tested (nil); after "glow" and a click on Cues > Pulsing glow: Pass (folded, on
    screen, Okay flat); negative: results shown again over the page: Fail.
Run: python3 tests/qa_walks_debug_w3_run.py"""
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
local def = QA and QA.walks["debug-w3"]
check("the W3 walkthrough is registered with pre-fill, for B287-B290", def ~= nil and def.prefill == true and def.qa == "B287, B288, B289, B290")
if not def then return R end
check("its last step is a Done step with no verdict", def.steps[#def.steps].done == true and def.steps[#def.steps].noVerdict == true)
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.05, 8); return st.check() end
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useCd = true; P.spellID = 203720; P.cdState = "ready"; ns.NormalizeRule(P)
table.insert(ns.rules, 1, P)
ns.NewCueRule(P, "icon")
pcall(ns.MarkDirty)

-- 1 (#478)
local ok1, n1 = run(1)
check("step 1: collapsed, the title-bar buttons stay put: Pass", ok1 == true, n1)
check("...the note has the right edges open / collapsed", tostring(n1):find("X ", 1, true) ~= nil and tostring(n1):find("arrow", 1, true) ~= nil, n1)
local ACD = LibStub("AceConfigDialog-3.0")
local c = ACD.OpenFrames.CueRules.xuiChrome
local p1 = { c.close:GetPoint(1) }
c.close:ClearAllPoints(); c.close:SetPoint("LEFT", ACD.OpenFrames.CueRules.titlebg, "RIGHT", 36, 0)   -- where 0.6.96 put it
local okN1 = def.steps[1].check()
check("negative: the X beside the title (the old collapsed anchor) gives Fail", okN1 == false)
c.close:ClearAllPoints(); c.close:SetPoint(p1[1], p1[2], p1[3], p1[4], p1[5])

-- 2 (#468)
local ok2, n2 = run(2)
check("step 2: the bottom Close, the arrow and the ? are flat: Pass", ok2 == true and not c.collapsed, n2)
local cb = ns.OptionsApi.FrameCloseButton(ACD.OpenFrames.CueRules)
cb.Left:SetAlpha(1)
local okN2, nN2 = def.steps[2].check()
check("negative: the Close button's red art showing gives Fail", okN2 == false and tostring(nN2):find("red art", 1, true) ~= nil, nN2)
cb.Left:SetAlpha(0)

-- 3 (#471)
local adv0 = ns.Settings("platform").ui and ns.Settings("platform").ui.themeAdvanced
local ok3, n3 = run(3)
check("step 3: Theme page: Accept flat, one Reset column inside the boxes, Delete saved inside the margin: Pass", ok3 == true, n3)
local function find(w, pred, out)
  out = out or {}
  if pred(w) then out[#out + 1] = w end
  for _, ch in ipairs(w.children or {}) do find(ch, pred, out) end
  return out
end
local function optName(w) local o = w.GetUserData and w:GetUserData("option"); return o and o.name end
local resets = find(ACD.OpenFrames.CueRules, function(w) return w.type == "Button" and optName(w) == "Reset" and w.frame:IsVisible() end)
local rf = resets[1] and resets[1].frame
local rp = rf and { rf:GetPoint(1) }
if rf then rf:ClearAllPoints(); rf:SetPoint(rp[1], rp[2], rp[3], (rp[4] or 0) - 40, rp[5]) end
local okN3 = def.steps[3].check()
check("negative: a Reset out of line gives Fail", rf ~= nil and okN3 == false)
if rf then rf:ClearAllPoints(); rf:SetPoint(rp[1], rp[2], rp[3], rp[4], rp[5]) end
local box = find(ACD.OpenFrames.CueRules, function(w) return w.type == "MultiLineEditBox" and optName(w) == "Theme string" end)[1]
box.button.Middle:SetAlpha(1)
local okN3b, nN3b = def.steps[3].check()
check("negative: the Accept button's red art showing gives Fail", okN3b == false and tostring(nN3b):find("red art", 1, true) ~= nil, nN3b)
box.button.Middle:SetAlpha(0)

-- 4 (#483)
local ok4, n4 = run(4)
check("step 4 before a result click: not tested (nil), it says what to do", ok4 == nil and tostring(n4):find("click one result", 1, true) ~= nil, tostring(ok4) .. " " .. tostring(n4))
local function findG(t, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.args and t.args.xuiSearch then return t end
  for _, v in pairs(t) do local r = findG(v, seen); if r then return r end end
end
local g = findG(ns.OptionsApi.LastTree())
local a = g.args
a.xuiSearch.set(nil, "glow"); W.tick(0.05, 4)
local hit
for i = 1, 12 do local o = a["xuiSR" .. i]; if not o.hidden() and o.name():find("Pulsing glow", 1, true) then hit = o end end
check("(\"glow\" lists Cues > Pulsing glow)", hit ~= nil)
if hit then hit.func() end
W.tick(0.05, 12)
ok4, n4 = def.steps[4].check()
check("step 4 after the click: results folded, Pulsing glow on screen, Okay flat: Pass", ok4 == true, n4)
check("...the note names the search and the option", tostring(n4):find("glow", 1, true) ~= nil and tostring(n4):find("Pulsing glow", 1, true) ~= nil, n4)
ns.OptionsApi.RuleEditor.RuleSearch.folded[P] = nil
local okN4, nN4 = def.steps[4].check()
check("negative: the results shown again over the page gives Fail", okN4 == false and tostring(nN4):find("folded: NO", 1, true) ~= nil, nN4)

-- 5 (done): Advanced customization back as it was
def.steps[5].setup()
local adv1 = ns.Settings("platform").ui and ns.Settings("platform").ui.themeAdvanced
check("Done: Advanced customization is back as it was before step 3", adv1 == adv0, tostring(adv1) .. " vs " .. tostring(adv0))
for i = #ns.rules, 1, -1 do if ns.rules[i] == P then table.remove(ns.rules, i) end end
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
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
