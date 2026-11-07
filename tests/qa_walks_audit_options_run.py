#!/usr/bin/env python3
"""The in-game QA walkthroughs for the settings-window audit fixes and FA-11 (XayaUI_DevAssist/QAWalks-audit-options.lua; standing rule
V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk
through with pre-fill confirmation options or data capturing").
On the real addons (Dev Assist on) in the stand-in game: the file is loaded the way the game would load it once it is in the toc (the
parent session adds it), every walkthrough is registered with prefill, every step runs in order without a Lua error, the verdicts the
stand-in can answer are Pass on the fixed code, and each last step leaves no QA test rule or group behind.
Run: python3 tests/qa_walks_audit_options_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, path)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
if not QA then check("Dev Assist QA framework", false); return R end
local f, err = loadfile(path)
check("the walkthrough file loads", f ~= nil, err)
if not f then return R end
f("XayaUI_DevAssist", {})
ns.Print = function() end
local ids = { "audit-opt-load", "audit-opt-lock", "audit-opt-group", "audit-opt-bin", "audit-opt-inputs" }
local want = { ["audit-opt-load"] = { [1] = true, [3] = true }, ["audit-opt-group"] = { [1] = true, [2] = true, [3] = true },
  ["audit-opt-bin"] = { [1] = true, [2] = true, [3] = true, [4] = true }, ["audit-opt-inputs"] = { [1] = true, [2] = true, [3] = true, [4] = true },
  ["audit-opt-lock"] = { [4] = true } }
local mine = 0
for _, r in ipairs(ns.rules or {}) do mine = mine + 1 end
for _, id in ipairs(ids) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill", d ~= nil and d.prefill == true and #d.steps >= 2, d and d.prefill)
  if d then
    for i, st in ipairs(d.steps) do
      local okS, errS = true, nil
      if st.setup then okS, errS = pcall(st.setup); W.tick(0.05, 2) end
      local okC, v, note = pcall(st.check)
      check(("%s step %d: Do it for me and the check run"):format(id, i), okS and okC, (not okS and errS) or (not okC and v) or "")
      if want[id] and want[id][i] then check(("%s step %d: verdict Pass"):format(id, i), okC and v == true, note) end
    end
  end
end
local left = 0
for _, r in ipairs(ns.rules or {}) do if r.qaAuditOpt then left = left + 1 end end
for _, fo in ipairs(ns.folders or {}) do if fo.qaAuditOpt then left = left + 1 end end
check("no QA test rule or group is left", left == 0, left)
check("the player's own rules are untouched (same count)", #ns.rules == mine, #ns.rules .. " vs " .. mine)
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
    path = os.path.join(os.path.dirname(HERE), "XayaUI_DevAssist", "QAWalks-audit-options.lua")
    res = L.eval("function(src, W, Ld, p) return loadstring(src)()(W, Ld, p) end")(LUA, world, loader, path)
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
