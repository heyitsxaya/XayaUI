"""Options 0.6.68: the settings window's open, click and idle cost (REQUEST-LOG A15 P-16; her in-game timing: a first open made 3 full
builds, "XayaUI open: 2603 ms" + 739 + 650 ms; a switch made 2 builds = 1,362 ms; reopen 776 + 1211 ms; XayaUI_Options at 528.5 MB).
Runs every addon in the whole-addon harness (tests/harness) with 40 rules and counts what the window does: full option-tree builds
(ns.BuildOptionsTable) per first open, per click and while idle; decorate / skin passes while idle; rebuilds when combat starts and ends;
memory kept after it closes. The stand-in's anchor resolution is memoised (as tests do not time the game's layout).
Negative control: Options 0.6.65 fails the first-open, click, idle-decorate, combat and kept-memory checks.
Run: python3 tests/options_open_cost_run.py   (needs: pip install lupa)"""
import os, sys
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "harness")
sys.path.insert(0, HERE)
import run as H  # noqa
folders = H.find_addons()
enabled = [n for n in folders if n != "XayaUI_DevAssist"]
L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(HERE, "world.lua"), api)
loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
    os.path.join(HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
out = L.eval("function(path, W, Ld) return dofile(path)(W, Ld) end")(os.path.join(os.path.dirname(os.path.abspath(__file__)), "options_open_cost.lua"), world, loader)
fails = 0
for i in range(1, len(out) + 1):
    print(out[i])
    if out[i].startswith("FAIL"): fails += 1
errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
if errs:
    print("FAIL  Lua errors in the stand-in: %d" % len(errs)); fails += 1
    for e in errs[:5]: print("   ", str(e)[:300])
print("FAILS: %d" % fails)
sys.exit(1 if fails else 0)
