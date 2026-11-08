#!/usr/bin/env python3
"""In-game QA walkthrough for debug batch W9b (XayaUI_DevAssist 0.7.68, XayaUI_DevAssist/QAWalks-debug-w9b.lua; QA B297-B300; issue
#472). Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game
qa test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game, with an element theme of her own already set (Tooltips: Color blind)
and the Esc Menu's "Use my own colors" saved before the update, and runs each step as a player would (Do it for me, then the check):
  - registered with pre-fill for B297-B300; step 4 is a question (noVerdict); the last step is a Done step that puts her scopes back;
  - before Do it for me: steps 1-3 say "not tested" (nil), never Pass;
  - step 1: Pass, the note has the five columns and the row count; step 2: Pass, Light's colours read back from the window, the
    note has before > after; negative: the window repainted by hand gives Fail; step 3: Pass, back to the colours before;
  - step 4: the note has the six Esc Menu colours (the ones saved before the update);
  - Done: her own element themes are exactly what they were (theme.scopes, through the Platform store).
Run: python3 tests/qa_walks_debug_w9b_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

GM = {"skin": True, "useColors": True, "bgR": 0.11, "bgG": 0.12, "bgB": 0.13, "pbR": 0.9, "pbG": 0.2, "pbB": 0.1, "btnR": 0.21, "btnG": 0.22,
      "btnB": 0.23, "bbR": 0.1, "bbG": 0.8, "bbB": 0.3, "accR": 0.2, "accG": 0.4, "accB": 0.95, "ttR": 0.95, "ttG": 0.9, "ttB": 0.05}

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
local def = QA and QA.walks["debug-w9b"]
check("the W9b walkthrough is registered with pre-fill, for B297-B300", def ~= nil and def.prefill == true and def.qa == "B297, B298, B299, B300")
if not def then return R end
check("step 4 is a question (no verdict from the addon)", def.steps[4].noVerdict == true)
check("its last step is a Done step", def.steps[#def.steps].done == true)
ns.Print = function() end
local T = ns.Theme
T.SetScopeTheme("reskin.tooltips", "colorblind")   -- her own element theme
local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}; for k in pairs(v) do keys[#keys + 1] = tostring(k) end; table.sort(keys)
  local o = {}; for _, k in ipairs(keys) do o[#o + 1] = k .. "=" .. ser(v[k]) end
  return "{" .. table.concat(o, ",") .. "}"
end
local P = ns.Settings("platform")
local before = ser(P.theme.scopes)
for i = 1, 3 do
  local ok, why = def.steps[i].check()
  check("step " .. i .. " before Do it for me: not tested (no verdict)", ok == nil, tostring(ok) .. " " .. tostring(why))
end
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.1, 8); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3); return st.check() end
local function has(note, s) return type(note) == "string" and note:find(s, 1, true) ~= nil end
local ok1, n1 = run(1)
check("step 1 (the table): Pass, the five columns and one row per element", ok1 == true and has(n1, "Columns: Element | Theme | Overrides | Comes from | Reset") and has(n1, "Rows: 16 of 16"), n1)
local ok2, n2 = run(2)
check("step 2 (Settings window on Light mode): Pass, before > after in the note", ok2 == true and has(n2, "> ffffff") and has(n2, "Comes from: this element") and #n2 <= 200, n2)
local fr = LibStub("AceConfigDialog-3.0").OpenFrames.CueRules.frame
fr:SetBackdropColor(0.2, 0.2, 0.2, 1)
local ok2n, n2n = def.steps[2].check()
check("step 2 negative: a window not drawn in Light's colours gives Fail", ok2n == false, tostring(ok2n) .. " " .. tostring(n2n))
local ok3, n3 = run(3)
check("step 3 (Reset): Pass, the colours before step 2 and Global", ok3 == true and has(n3, "Comes from: Global"), n3)
local ok4, n4 = def.steps[4].check()
check("step 4 (Esc Menu): the note has the six colours saved before the update", ok4 == true and has(n4, "panel fill 1c1f21") and has(n4, "title f2e60d") and not has(n4, "Not the old"), n4)
def.steps[#def.steps].setup(); W.tick(0.1, 4)
check("Done: her own element themes are exactly what they were", ser(P.theme.scopes) == before, ser(P.theme.scopes) .. " vs " .. before)
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders},
                                                                "saved": {"XayaUI_Reskin": {"XayaUIReskinDB": {"gm": GM}}}}))
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
