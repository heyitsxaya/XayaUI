"""#351 phase 1 (Xaya, 2026-11-03: "set a standard gutter and margin so that all elements are not smushed directly into their container
bounds"), the settings window: one margin and one gutter, defined once in Skin.lua (ns.UI_MARGIN / ns.UI_GUTTER), and the gutter between
EVERY two controls on a row. Before, ns.FlexPrepass added it only when the row stretched a control or held a compact button, so rows of
fixed-width controls (labels, icons, colour pickers, images, relative widths) touched each other.
Runs the real Skin.lua layout pass (from `local mfs` to the end of ns.FlexPrepass) on stand-in AceGUI widgets.
Run: python3 tests/ui_gutter_run.py   (needs: pip install lupa)"""
import os, re, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
skin = open(os.path.join(ROOT, "XayaUI_Options", "Skin.lua"), encoding="utf-8").read()
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)
# #351 phase 2: the values are defined once in core (XayaUI/Modules.lua); Skin.lua reads them (its 10s are only the fallback for
# stand-in tests that load Skin.lua without core)
modules = open(os.path.join(ROOT, "XayaUI", "Modules.lua"), encoding="utf-8").read()
# (core 0.6.61, UI-47) they live in core's ns.Style table (margin, gutter); ns.UI_MARGIN / ns.UI_GUTTER read from it
m = re.search(r"^ns\.Style = \{.*?\bmargin = (\d+),.*?\bgutter = (\d+),", modules, re.S | re.M)
check("the margin and the gutter are defined once, in core (XayaUI/Modules.lua: ns.Style, read by ns.UI_MARGIN / ns.UI_GUTTER)", m is not None
      and re.search(r"^ns\.UI_MARGIN, ns\.UI_GUTTER = ns\.Style\.margin, ns\.Style\.gutter\b", modules, re.M) is not None)
check("Skin.lua reads them from core", re.search(r"^local UI_MARGIN, UI_GUTTER = ns\.UI_MARGIN or 10, ns\.UI_GUTTER or 10$", skin, re.M) is not None
      and "ns.UI_MARGIN, ns.UI_GUTTER = UI_MARGIN" not in skin)
MARGIN, GUTTER = (int(m.group(1)), int(m.group(2))) if m else (10, 10)
insets = re.findall(r'content:SetPoint\("TOPLEFT", (?:w\.border, "TOPLEFT", )?(\S+?)[ ,]', skin)
literal = [x for x in insets if x in ("10", "10,")]
check("every inset XayaUI sets on a content area reads UI_MARGIN (AceGUI's own 10 is restored only on release)",
      skin.count("UI_MARGIN + pad") >= 2 and "UI_MARGIN + ind" in skin, insets)
a = skin.index("local mfs\n")
mm = re.search(r"^function ns\.FlexPrepass\(.*?^end\n", skin[a:], re.S | re.M)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
UIParent = { CreateFontString = function() return { SetPoint = function() end, SetAlpha = function() end,
  SetText = function(self, t) self.t = t end, GetStringWidth = function(self) return #(self.t or "") * 6 end } end }
CueRulesDB = {}
ns = { GridOn = function() return false end, UI_GUTTER = __G__ }
SkinOn = function() return true end
function W(kind, width, opt)
  local c = { type = kind, frame = { width = width } }
  function c:SetWidth(x) self.frame.width = x end
  function c.frame:GetWidth() return self.width end
  c.GetUserData = function(_, k) if k == "option" then return opt end end
  c.text = { GetUnboundedStringWidth = function() return 40 end, GetStringWidth = function() return 40 end }
  return c
end
'''.replace("__G__", str(GUTTER)))
ms = re.search(r"^ns\.Style = \{.*?^\}\n", modules, re.S | re.M)   # (UI-47: the slice reads core's ns.Style)
assert ms, "ns.Style not found in XayaUI/Modules.lua"
L.execute("local ns = ns\n" + ms.group(0))
L.execute("local ns = ns\n" + skin[a:a + mm.end()])
def gaps(lua_rows, width=640):
    return L.eval('''(function(width)
      local row = { %s }
      ns.FlexPrepass({ width = width }, row)
      local out = {}
      for i, c in ipairs(row) do out[i] = c.xuiGapX or 0 end
      return out
    end)''' % lua_rows)(width)
g = gaps('W("Label", 120), W("Label", 120), W("Label", 120)')
check("three labels on a row: %d px between each (they touched)" % GUTTER, g[1] == 0 and g[2] == GUTTER and g[3] == GUTTER, [g[1], g[2], g[3]])
g = gaps('W("Icon", 32), W("Label", 200)')
check("an icon and its label: the gutter between them", g[2] == GUTTER, g[2])
g = gaps('W("ColorPicker", 150), W("ColorPicker", 150), W("Image", 64)')
check("colour pickers and an image: the gutter between each", g[2] == GUTTER and g[3] == GUTTER, [g[2], g[3]])
g = gaps('W("Label", 320), W("Label", 320)', 640)
check("two labels that only fit without the gutter: the second one wraps to the next row (no overflow, no touching)", g[2] == 0, g[2])
g = gaps('W("Button", 64, { type = "execute", name = "Group", arg = { xuiTab = true } }), W("Button", 64, { type = "execute", name = "Display", arg = { xuiTab = true } })')
check("tabs drawn as buttons keep 2 px (#370)", g[2] == 2, g[2])
g = gaps('W("CheckBox", 200), W("Slider", 200)')
check("rows that stretch a control keep the same gutter as before", g[2] == GUTTER, g[2])
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
