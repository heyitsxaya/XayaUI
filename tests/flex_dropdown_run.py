"""#352 (Options 0.6.12): a dropdown alone on its row must not stretch across the whole pane (Xaya's standing rule: "a dropdown must
never take a whole row by itself"). Runs the real Skin.lua layout pass (ns.FlexPrepass, from `local mfs` to its end) against
stand-in widgets and checks the widths it sets.
Run: python3 tests/flex_dropdown_run.py   (needs: pip install lupa)"""
import os, re, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
skin = open(os.path.join(ROOT, "XayaUI_Options", "Skin.lua"), encoding="utf-8").read()
a = skin.index("local mfs\n")
m = re.search(r"^function ns\.FlexPrepass\(.*?^end\n", skin[a:], re.S | re.M)
assert m, "FlexPrepass not found in Skin.lua"
chunk = skin[a:a + m.end()]
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
UIParent = { CreateFontString = function() return { SetPoint = function() end, SetAlpha = function() end,
  SetText = function(self, t) self.t = t end, GetStringWidth = function(self) return #(self.t or "") * 6 end } end }
CueRulesDB = {}
ns = { GridOn = function() return GRID end }
GRID = true
function W(kind, w, opts)
  local c = { type = kind, frame = { width = w }, list = opts }
  function c:SetWidth(x) self.frame.width = x end
  function c.frame:GetWidth() return self.width end
  return c
end
CONTENT = { width = 600 }
''')
L.execute("local ns = ns\n" + chunk)
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)
colW = (600 - 30) // 2
w = L.eval("(function() local d = W('Dropdown', 200, { a = 'Short' }); ns.FlexPrepass(CONTENT, { d }); return d.frame.width end)()")
check("grid: a dropdown alone on its row stays one column wide (%d px), not the whole pane (600)" % colW, w == colW, w)
w2 = L.eval("(function() local a, b = W('Dropdown', 200, { a = 'x' }), W('Dropdown', 200, { a = 'y' }); ns.FlexPrepass(CONTENT, { a, b }); return a.frame.width, b.frame.width end)()")
check("grid: two dropdowns share the row, one column each", tuple(w2) == (colW, colW), w2)
w3 = L.eval("(function() local d = W('Dropdown', 200, { a = string.rep('a', 70) }); ns.FlexPrepass(CONTENT, { d }); return d.frame.width end)()")
check("grid: a dropdown whose longest option needs more than a column still fits it", w3 >= 70 * 6 + 40, w3)
w4 = L.eval("(function() local s = W('Slider', 200); ns.FlexPrepass(CONTENT, { s }); return s.frame.width end)()")
check("other controls alone on a row are unchanged (a slider still spans the pane, within the existing 1 px rounding)", w4 >= 599, w4)
L.execute("GRID = false")
w5 = L.eval("(function() local d = W('Dropdown', 220, { a = 'Short' }); ns.FlexPrepass(CONTENT, { d }); return d.frame.width end)()")
check("no grid: a lone dropdown keeps its own width (220), not the whole pane", w5 == 220, w5)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
