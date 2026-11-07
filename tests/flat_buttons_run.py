"""#286 (core 0.6.16 / Options 0.6.12): every button built from Blizzard's red UIPanelButtonTemplate takes XayaUI's flat look.
Part 1 runs the real ns.FlatButton (Core.lua): styled at once by core's own look (UI-77, core 0.6.68: no longer a service of the
settings addon), and again on every show (so it follows the skin switch); core never calls the settings addon by name.
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

# ---- part 1: the helper itself. UI-77 (core 0.6.68): the look is core's own (ns.PaintFlatButton), so core's windows are flat
# without the settings addon (LoadOnDemand); the "buttonSkin" service is gone. tests/core_flat_buttons_run.py runs it in the stand-in game.
core = open(os.path.join(ROOT, "XayaUI", "Core.lua"), encoding="utf-8").read()
m = re.search(r"^function ns\.FlatButton\(b, primary\)\n.*?^end\n", core, re.S | re.M)
check("Core.lua defines ns.FlatButton", m is not None)
check("Core.lua defines the look itself (ns.PaintFlatButton)", re.search(r"^function ns\.PaintFlatButton\(b, primary\)", core, re.M) is not None)
if m:
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(r'''
    ns = {}
    PAINTED = {}
    function ns.PaintFlatButton(b, primary) PAINTED[#PAINTED + 1] = { b = b, primary = primary } end
    function NewButton() local b = { hooks = {} }
      function b:HookScript(k, fn) self.hooks[k] = fn end
      return b end
    ''')
    pre = core[:m.start()]
    lst = re.search(r"^local flatButtons.*?^end\n", pre, re.S | re.M)
    L.execute((lst.group(0) if lst else "") + m.group(0))
    L.execute("B = NewButton(); ns.FlatButton(B)")
    check("styled at once by core's own look (no settings addon needed)", L.eval("#PAINTED == 1 and PAINTED[1].b == B"))
    L.execute("P = NewButton(); ns.FlatButton(P, true)")
    check("a primary button stays primary", L.eval("PAINTED[2].primary == true"))
    L.execute("P.hooks.OnShow(P)")
    check("styled again on every show (follows the skin switch)", L.eval("#PAINTED == 3"))

# ---- the contract: core never names the settings addon's function (Modules.lua rule); the settings addon calls core's look
for path in glob.glob(os.path.join(ROOT, "XayaUI", "**", "*.lua"), recursive=True):
    txt = re.sub(r"--[^\n]*", "", open(path, encoding="utf-8").read())
    if "ns.SkinPlainButton" in txt:
        check("core file %s does not call ns.SkinPlainButton (XayaUI_Options) by name" % os.path.relpath(path, ROOT), False)
skin = open(os.path.join(ROOT, "XayaUI_Options", "Skin.lua"), encoding="utf-8").read()
check("the settings addon's ns.SkinPlainButton uses core's look (one copy)", "ns.PaintFlatButton(b, primary)" in skin)

# ---- part 2: every red-template button in the addons
KEEP = {   # file name -> reason the button keeps Blizzard's look
    ("Modules.lua", "btn"): "the 'Open XayaUI' button inside Blizzard's own Settings panel matches that panel",
    ("Options.lua", "c.arrow"): "the window's collapse button pairs with Blizzard's close X in the title ribbon",
    ("Options.lua", "c.help"): "the window's ? sits beside the collapse button and the close X in the title ribbon, same look (Options 0.6.56)",
    ("InfoPane.lua", "b"): "the version pane's title-bar ? and collapse buttons (TitleButton) pair with its close X, as in the settings window",
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
