#!/usr/bin/env python3
"""Round-2 review follow-up (goldens, U5-rulestree): the Rules > Smart Categories sidebar was 230 or 204 px wide depending on which
pooled AceGUI widget the window rebuild got. AceGUI hands out a released widget with next(), in memory-address order, so in the game
either order can happen (INFERENCE, UNVERIFIED IN GAME). A pooled tab group still sized from an earlier, narrower use runs one
layout pass at that stale width, and AceGUI's TreeGroup caps the sidebar at min(400, width - 50) and never gives the width back.
XayaUI_Options/Skin.lua ns.EnsureNameRoom, run again from every decorate pass (TreePaint.lua DecorateTree), now gives it back.

What she sees, checked here with the real addons in the stand-in game (tests/tree_paint_parity_run.py's drawing):
  1. Smart Categories is drawn the same (every row, its name and sub-line width) whichever pooled widget AceGUI hands out first
     (last released first, "lifo", or first released first, "fifo"), and it is the 230 px drawing of the golden;
  2. every other Rules / Profiles / Settings drawing is the same in both orders;
  3. a sidebar width she dragged by hand (300 px) that a layout pass at a stale, narrow width capped is given back on the next
     decorate pass, up to AceGUI's own limit; a narrow window keeps the cap.
Each numbered check fails on the code before this change. Run: python3 tests/fix_r3_sidebar_width_run.py"""
import hashlib, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import tree_paint_parity_run as T  # noqa: E402
import run as H  # noqa: E402

MANUAL = r'''
return function(W, L)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns.ToggleUI then pcall(ns.ToggleUI) end
W.tick(0.1, 6)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
pcall(ACD.SelectGroup, ACD, "CueRules", "cooldowns", "smartTab")
W.tick(0.2, 4); if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 2)
local tree
local function find(w, d) if not w or d > 16 or tree then return end if w.type == "TreeGroup" and w.frame:IsShown() then tree = w end for _, c in ipairs(w.children or {}) do find(c, d + 1) end end
find(ACD.OpenFrames.CueRules, 0)
if not tree then return "no tree" end
local st = tree.status or tree.localstatus
local full = st.fullwidth
-- she drags the sidebar to 300 px (Skin.lua's drag: Finish records her width)
st.treewidth = 300; st.xuiManualWidth = true; st.xuiManualTW = 300
tree:SetTreeWidth(300, st.treesizable)
local out = { full = full, dragged = st.treewidth }
-- a layout pass at a stale, narrow width (a pooled container's old size): AceGUI caps the sidebar
tree:OnWidthSet(254)
out.capped = st.treewidth
-- the real width again, then the next decorate pass
tree:OnWidthSet(full)
if ns.DecorateTrees then pcall(ns.DecorateTrees) end
out.after = st.treewidth
-- a window that really is narrow keeps AceGUI's cap
tree:OnWidthSet(300)
local stw, nSet = tree.SetTreeWidth, 0
tree.SetTreeWidth = function(...) nSet = nSet + 1; return stw(...) end
if ns.DecorateTrees then pcall(ns.DecorateTrees) end
tree.SetTreeWidth = stw
out.narrow = st.treewidth
tree:OnWidthSet(full); if ns.DecorateTrees then pcall(ns.DecorateTrees) end
out.back = st.treewidth
return string.format("full=%s dragged=%s capped=%s after=%s narrow=%s back=%s", tostring(out.full), tostring(out.dragged),
  tostring(out.capped), tostring(out.after), tostring(out.narrow), tostring(out.back)) .. " resizes in the narrow pass=" .. nSet,
  out.full, out.capped, out.after, out.narrow, out.back, nSet
end
'''


def manual():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return {loadstring(src)()(W, Ld)} end")(MANUAL, world, loader)
    vals = [res[i] for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return vals, errs


def sub_widths(text):
    out = []
    for line in text.split("\n"):
        if line.strip().startswith("xuiSub"):
            parts = line.split()
            out.append(next((p for p in parts if "x" in p and p[0].isdigit()), "?"))
    return out


def main():
    results = []

    def check(name, ok, detail=""):
        results.append((name + (("  [" + str(detail) + "]") if detail and not ok else ""), bool(ok)))

    gold = json.load(open(T.GOLDEN_FILE))["on"]
    lifo = T.run_variant(True, "lifo")
    fifo = T.run_variant(True, "fifo")
    ltabs, ftabs = lifo[0], fifo[0]
    sha = lambda s: hashlib.sha256(s.encode()).hexdigest()
    ls, fs = ltabs.get("rules-smart", ""), ftabs.get("rules-smart", "")
    check("(test set-up) both pool orders drew Smart Categories, no AceGUI widget was released before the order was fixed",
          ls and fs and lifo[5] == 0 and fifo[5] == 0, "lifo %s / fifo %s released before" % (lifo[5], fifo[5]))
    check("1. Smart Categories: the same sidebar (row names and sub-line widths) whichever pooled widget AceGUI hands out first",
          ls == fs, "sub-line widths lifo %s / fifo %s" % (sub_widths(ls), sub_widths(fs)))
    check("1. ...and it is the 230 px drawing of the golden in both orders",
          sha(ls) == gold["rules-smart"]["sha"] and sha(fs) == gold["rules-smart"]["sha"], "fifo sub-line widths %s" % sub_widths(fs))
    diff = [k for k in sorted(set(ltabs) | set(ftabs)) if ltabs.get(k) != ftabs.get(k)]
    check("2. every drawing (Rules lists, Profiles, Settings) is the same in both pool orders", not diff, "differ: %s" % diff)
    check("(regression) no Lua error in either order", not lifo[3] and not fifo[3], "; ".join(str(e)[:300] for e in (lifo[3] + fifo[3])[:3]))
    vals, errs = manual()
    desc = vals[0] if vals else "nothing"
    if len(vals) >= 6:
        full, capped, after, narrow, back, nset = vals[1:7]
        check("(test set-up) a layout pass at a stale 254 px width caps her dragged 300 px sidebar (AceGUI's own cap)", capped == 204, desc)
        check("3. her dragged 300 px sidebar is given back on the next decorate pass at the real width", after == 300, desc)
        check("3. ...a really narrow window (300 px) keeps AceGUI's cap, and widening it gives her 300 px back", narrow == 250 and back == 300, desc)
        check("(regression) ...and the decorate pass in the narrow window does not resize the sidebar (no width asked for only to be capped again)", nset == 0, desc)
    else:
        check("(test set-up) the Smart Categories tree was found", False, desc)
    check("(regression) no Lua error in the drag case", not errs, "; ".join(str(e)[:300] for e in errs[:3]))
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
