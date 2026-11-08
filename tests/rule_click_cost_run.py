"""Debug W7 (#467, Options 0.6.100): what one click that changes a rule costs, measured and counted in the whole-addon stand-in.
Her report (J31, 2026-11-07): toggling a switch in an open rule's editor took 136 to 221 ms ("82 ms build and draw + 54 ms skin",
"129 + 92"); "modifying an actual rule in any meaningful way is the fail state".
Loads every addon (tests/harness), makes 313 rules in nested groups (her shape, REQUEST-LOG A15 P-16), opens the window on one rule's
Display tab and clicks one of its tick boxes (the widget's own OnValueChanged: AceConfigDialog runs the option's set, then redraws).
Each phase of the click is timed with os.clock (exclusive time) and its game calls (every widget method, CreateFrame) are counted;
the table is printed as "info" lines. Stand-in timings are not the game's milliseconds (INFERENCE): compare ratios and counts.
Checks:
  A the click redraws the window once, builds the options table once and the open rule's editor once;
  B the skin pass's minimum-width scan (Skin.lua ScanDropdowns: the widest text of any dropdown in the tree) makes no game call on a
    repeat click: the text widths it measured before are kept. Options 0.6.99 measured every text again on every rule-editor click
    (13,054 texts, 26,108 game calls) and fails B;
  C its answer is the same as measuring every text again (an independent walk of the window's tree with its own font string), on
    every click, for another rule, after the measuring string's font changes (the kept widths are dropped and measured again) and
    with a new dropdown text;
The stand-in's anchor resolution is not memoised here (tests/options_click_cost.lua does it): its stale cache moved the sidebar's
geometry. AceGUI hands back a pooled widget with next(pool), so which pooled tree a redraw gets depends on memory addresses: the
test empties the tree pool once the window is open so every click reuses the window's own tree (the sidebar's counts are then the
same from run to run; they are printed, not checked).
Run: python3 tests/rule_click_cost_run.py   (needs: pip install lupa)"""
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
out = L.eval("function(path, W, Ld) return dofile(path)(W, Ld) end")(os.path.join(os.path.dirname(os.path.abspath(__file__)), "rule_click_cost.lua"), world, loader)
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
