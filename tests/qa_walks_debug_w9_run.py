#!/usr/bin/env python3
"""In-game QA walkthrough for debug batch W9a (XayaUI_DevAssist 0.7.67, XayaUI_DevAssist/QAWalks-debug-w9.lua; QA B294-B296; issue
#460). Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game
qa test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game, starting from a theme of her own (Custom on Light mode, one colour
changed), and runs each step as a player would (Do it for me, then the check):
  - registered with pre-fill for B294-B296; step 2 is a question (noVerdict); the last step is a Done step that puts her theme back;
  - before Do it for me: each check says "not tested" (nil), never Pass;
  - step 1 (Rainbow): Pass, the note has every element's colours read back from its border (window, pane, button, arrow, tab);
    negative: one border repainted solid by hand gives Fail and names it;
  - step 3 (Reverse): Pass with the colours reversed; negative: the switch turned off again without Do it for me gives "not tested";
  - step 4 (Class colors): Pass, no gradient left; negative: a gradient left on the window gives Fail;
  - Done: her theme is exactly what it was (every key of CueRulesDB.theme).
Run: python3 tests/qa_walks_debug_w9_run.py"""
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
local def = QA and QA.walks["debug-w9"]
check("the W9a walkthrough is registered with pre-fill, for B294-B296", def ~= nil and def.prefill == true and def.qa == "B294, B295, B296")
if not def then return R end
check("step 2 is a question (no verdict from the addon)", def.steps[2].noVerdict == true)
check("its last step is a Done step", def.steps[#def.steps].done == true)
ns.Print = function() end
local T = ns.Theme
-- her own theme
T.SetBase("light"); T.SetToken("accent", { 0.9, 0.1, 0.5, 1 }); T.SetSize("L")
local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}; for k in pairs(v) do keys[#keys + 1] = tostring(k) end; table.sort(keys)
  local o = {}; for _, k in ipairs(keys) do o[#o + 1] = k .. "=" .. ser(v[k] == nil and v[tonumber(k)] or v[k]) end
  return "{" .. table.concat(o, ",") .. "}"
end
local before = ser(CueRulesDB.theme)
for i, st in ipairs(def.steps) do
  if st.check and st.setup and i ~= 2 then
    local ok, why = st.check()
    check("step " .. i .. " before Do it for me: not tested (no verdict)", ok == nil, tostring(ok) .. " " .. tostring(why))
  end
end
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.1, 8); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3); return st.check() end
local function has(note, s) return type(note) == "string" and note:find(s, 1, true) ~= nil end

local ok1, n1 = run(1)
check("step 1 (Rainbow): Pass", ok1 == true, n1)
check("step 1: the note has the colours and each element's reading (window, pane, button, arrow, tab), within the 200 characters a result keeps",
  has(n1, "Rainbow ff3333>ffb31a>f2ff33>40e659>408cff>a64df2") and has(n1, "window =") and has(n1, "pane =") and has(n1, "button =") and has(n1, "arrow =") and has(n1, "tab =") and #n1 <= 200, n1)
-- negative: one border painted solid by hand
local root = LibStub("AceConfigDialog-3.0").OpenFrames.CueRules
local tab
for _, g in ipairs((function() local o = {}; local function f(w) if type(w) ~= "table" then return end; if w.type == "TabGroup" and w.tabs then o[#o + 1] = w end; for _, c in ipairs(w.children or {}) do f(c) end end; f(root); return o end)()) do
  for _, t in ipairs(g.tabs) do if t:IsShown() and t.selected and t.xuiGradE then tab = t end end
end
if tab then T.PaintEdges(tab, tab.xuiFlat.e, { 1, 1, 1, 1 }, nil) end
local okN, nN = def.steps[1].check()
check("step 1 negative: a border drawn solid gives Fail and names it", okN == false and has(nN, "Wrong: tab") and has(nN, "tab solid"), tostring(okN) .. " " .. tostring(nN))
local ok2, n2 = def.steps[2].check()
check("step 2 (her eye): the check only captures the colours", ok2 == true and has(n2, "Rainbow"), n2)

local ok3, n3 = run(3)
check("step 3 (Reverse): Pass, colours reversed (purple first)", ok3 == true and has(n3, "Reversed a64df2>") and has(n3, "window ="), n3)
T.SetGradReverse(false)
local ok3b = def.steps[3].check()
check("step 3 negative: the switch off again gives no verdict", ok3b == nil)

local ok4, n4 = run(4)
check("step 4 (Class colors): Pass, no gradient left", ok4 == true and has(n4, "gradients left on none"), n4)
local fr = root.frame
T.PaintEdges(fr, T.EdgeBox(fr, "BORDER", 7), { 1, 1, 1, 1 }, { stops = { { 1, 0, 0, 1 }, { 0, 0, 1, 1 } } })
local ok4n, n4n = def.steps[4].check()
check("step 4 negative: a gradient left on the window gives Fail", ok4n == false and has(n4n, "window"), tostring(ok4n) .. " " .. tostring(n4n))

def.steps[#def.steps].setup(); W.tick(0.1, 4)
check("Done: her theme is exactly what it was", ser(CueRulesDB.theme) == before, ser(CueRulesDB.theme) .. " vs " .. before)
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
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
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
