"""#286 (core 0.6.16 / Options 0.6.12): every button built from Blizzard's red UIPanelButtonTemplate takes XayaUI's flat look.
Part 1 runs the real ns.FlatButton (Core.lua) against a stand-in button: styled at once when the settings addon is loaded, again on
every show (so it follows the skin switch), and left alone when the settings addon is not loaded.
Part 2 scans every addon's Lua: each UIPanelButtonTemplate button must be styled (ns.FlatButton / ns.SkinPlainButton / the
multi-select bar's own flat code) within a few lines of where it is made, or be on the short list of buttons that keep Blizzard's
look on purpose (with the reason).
Run: python3 tests/flat_buttons_run.py   (needs: pip install lupa)"""
import glob, os, re, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

# ---- part 1: the helper itself
core = open(os.path.join(ROOT, "XayaUI", "Core.lua"), encoding="utf-8").read()
m = re.search(r"^function ns\.FlatButton\(b, primary\)\n.*?^end\n", core, re.S | re.M)
check("Core.lua defines ns.FlatButton", m is not None)
if m:
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute("ns = {}\n" + m.group(0))
    L.execute(r'''
    SKINNED = {}
    function NewButton() local b = { hooks = {} }
      function b:HookScript(k, fn) self.hooks[k] = fn end
      return b end
    ''')
    L.execute("B = NewButton(); ns.FlatButton(B)")
    check("settings addon not loaded: the button keeps Blizzard's look, no error", L.eval("next(SKINNED) == nil"))
    L.execute("ns.SkinPlainButton = function(b, primary) SKINNED[#SKINNED + 1] = { b = b, primary = primary } end")
    L.execute("B.hooks.OnShow(B)")
    check("settings addon loaded later: styled when the button is next shown", L.eval("#SKINNED == 1 and SKINNED[1].b == B"))
    L.execute("SKINNED = {}; P = NewButton(); ns.FlatButton(P, true)")
    check("settings addon loaded: styled at once, and a primary button stays primary", L.eval("#SKINNED == 1 and SKINNED[1].primary == true"))
    L.execute("P.hooks.OnShow(P)")
    check("styled again on every show (follows the skin switch)", L.eval("#SKINNED == 2"))

# ---- part 2: every red-template button in the addons
KEEP = {   # file name -> reason the button keeps Blizzard's look
    ("Modules.lua", "btn"): "the 'Open XayaUI' button inside Blizzard's own Settings panel matches that panel",
    ("Options.lua", "c.arrow"): "the window's collapse button pairs with Blizzard's close X in the title ribbon",
}
STYLED = re.compile(r"FlatButton|SkinPlainButton|xuiFlatBtn")
for path in sorted(glob.glob(os.path.join(ROOT, "XayaUI*", "**", "*.lua"), recursive=True)):
    if os.sep + "Libs" + os.sep in path:
        continue
    lines = open(path, encoding="utf-8").read().split("\n")
    for i, ln in enumerate(lines):
        mm = re.search(r"(?:local\s+)?([\w.]+)\s*=\s*CreateFrame\(\"Button\",[^)]*\"UIPanelButtonTemplate\"\)", ln)
        if not mm:
            continue
        var, fname = mm.group(1), os.path.basename(path)
        if (fname, var) in KEEP:
            check("%s:%d %s keeps Blizzard's look on purpose (%s)" % (fname, i + 1, var, KEEP[(fname, var)]), True)
            continue
        window = "\n".join(lines[i:i + 30])
        check("%s:%d %s gets the flat look" % (fname, i + 1, var), STYLED.search(window) is not None)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
