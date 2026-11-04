"""#368 (Xaya 2026-11-04, screenshot): compact action buttons on the group page read "Gro...", "Displ...", "Delete gro...".
Runs the real Skin.lua layout pass (ns.FlexPrepass and the compact-button sizing before it, from `local mfs` to its end) against
stand-in AceGUI buttons whose label is pinned between two anchors 15 px in from each side (as AceGUI-3.0's Button does), so the
label's box is the button's width minus 30 px. The stand-in label answers GetStringWidth() with the width of the text as it fits
in that box (never wider than the box) and GetUnboundedStringWidth() with the width of the whole text. Checks that every button ends
wide enough for its whole label, after several layout passes, from any starting width.
INFERENCE (marked in the debug log): the live client's GetStringWidth on a bounded FontString returns the fitted width; Blizzard's
own UI sizes text-fitted controls with GetUnboundedStringWidth (UIDropDownMenu.lua:811 / 1366, SecureUtil.lua:78, 12.1.5 live).
Run: python3 tests/compact_button_width_run.py   (needs: pip install lupa)"""
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
ns = { GridOn = function() return false end }
SkinOn = function() return true end
CHAR = 7   -- px per character of the stand-in font
-- an AceGUI-style button: its label sits between 15 px insets, so the label's box is (button width - 30)
function Btn(label, startW)
  local c = { type = "Button", frame = { width = startW } }
  c.text = {
    GetUnboundedStringWidth = function() return #label * CHAR end,
    GetStringWidth = function() return math.min(#label * CHAR, math.max(0, c.frame.width - 30)) end,
  }
  function c:SetWidth(x) self.frame.width = x end
  function c.frame:GetWidth() return self.width end
  c.GetUserData = function(_, k) if k == "option" then return { type = "execute", name = label } end end
  c.label = label
  return c
end
function Run(content, buttons, passes) for _ = 1, passes do ns.FlexPrepass(content, buttons) end end
''')
L.execute("local ns = ns\n" + chunk)
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

# the group page's buttons as in the screenshot, each starting narrower than its label (the state the screenshot shows)
labels = ["Group", "Display", "Load", "Delete group", "Delete with contents", "+ New rule", "+ Nested group", "Enable all", "Disable all"]
res = L.eval('''(function(labels)
  local out = {}
  for i = 1, #labels do
    local b = Btn(labels[i], 64)
    Run({ width = 640 }, { b }, 3)
    out[i] = { w = b.frame.width, need = #labels[i] * 7, box = b.frame.width - 30 }
  end
  return out
end)''')(L.table_from(labels))
for i, lab in enumerate(labels, 1):
    r = res[i]
    check("'%s' starting at 64 px: after 3 layout passes its whole label fits (label %d px, box %d px)" % (lab, r.need, r.box),
          r.box >= r.need, (r.w, r.need))

# from a wide start the width settles at the label's width (+ padding), not at the start width
w = L.eval("(function() local b = Btn('Load', 300); Run({ width = 640 }, { b }, 2); return b.frame.width end)()")
check("'Load' starting at 300 px: shrinks to its label plus padding (28 + 34 = 62, minimum 64)", w == 64, w)
w = L.eval("(function() local b = Btn('Delete with contents', 300); Run({ width = 640 }, { b }, 5); return b.frame.width end)()")
check("'Delete with contents' starting at 300 px: 140 + 34 = 174, and stays there on later passes", w == 174, w)

# a client without GetUnboundedStringWidth still sizes from GetStringWidth (fallback)
w = L.eval('''(function()
  local b = Btn('Group', 300); b.text.GetUnboundedStringWidth = nil
  Run({ width = 640 }, { b }, 1); return b.frame.width end)()''')
check("no GetUnboundedStringWidth: falls back to GetStringWidth (Group 35 + 34 = 69)", w == 69, w)

# a row of buttons wider than the pane wraps instead of running past its right edge (the screenshot's "+ Nested gr")
res = L.eval('''(function()
  local row = { Btn("Delete group", 64), Btn("Delete with contents", 64), Btn("+ New rule", 64), Btn("+ Nested group", 64) }
  local content = { width = 560 }
  Run(content, row, 3)
  local out = {}
  for i, b in ipairs(row) do out[i] = { w = b.frame.width, gap = b.xuiGapX or 0 } end
  return out
end)()''')
total = sum(res[i].w + res[i].gap for i in range(1, 5))
check("four group buttons: each sized to its label (none below its label + padding)",
      all(res[i].w - 30 >= len(lab) * 7 + 4 for i, lab in enumerate(["Delete group", "Delete with contents", "+ New rule", "+ Nested group"], 1)),
      [res[i].w for i in range(1, 5)])
# #370: buttons drawn as tabs sit 2 px apart (a tab row); ordinary buttons keep the 10 px gap
res = L.eval('''(function()
  local function Tab(label) local b = Btn(label, 64); b.GetUserData = function(_, k) if k == "option" then return { type = "execute", name = label, arg = { xuiTab = true } } end end; return b end
  local row = { Tab("Group"), Tab("Display"), Tab("Load") }
  Run({ width = 640 }, row, 2)
  local btns = { Btn("Enable all", 64), Btn("Disable all", 64) }
  Run({ width = 640 }, btns, 2)
  return { row[2].xuiGapX, row[3].xuiGapX, row[1].xuiGapX, btns[2].xuiGapX, row[1].frame.width - 30 >= 35 }
end)()''')
check("tabs drawn as buttons: 2 px between them, none before the first; ordinary buttons keep 10 px",
      res[1] == 2 and res[2] == 2 and res[3] is None and res[4] == 10 and res[5] is True, [res[i] for i in range(1, 6)])
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
