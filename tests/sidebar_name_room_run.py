"""#369 (Xaya 2026-11-04, screenshot): nested Rules-sidebar rows showed 1-3 characters of their names ("VD...", "A...", "F...").
Runs the real ns.EnsureNameRoom (XayaUI_Options/Skin.lua) against a stand-in AceGUI tree: rows whose name starts xuiTextL px from
the row's left edge and ends xuiTextR px from its right edge (as DecorateButton records them), and a SetTreeWidth that resizes the
rows like AceGUI (row width = tree width - 22 for the scroll bar column, an assumption of the stand-in). Checks that every visible
row ends with at least 80 px for its name, that the sidebar only ever widens, that AceGUI's limit (min(400, window - 50)) holds, and
that empty / hidden rows are ignored.
Run: python3 tests/sidebar_name_room_run.py   (needs: pip install lupa)"""
import os, re, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
skin = open(os.path.join(ROOT, "XayaUI_Options", "Skin.lua"), encoding="utf-8").read()
m = re.search(r"^local NAME_ROOM = .*?^function ns\.EnsureNameRoom\(.*?^end\n", skin, re.S | re.M)
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)
check("ns.EnsureNameRoom exists in Skin.lua", m is not None)
if m:
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(r'''
ns = {}
SB = 22   -- scroll bar column in the stand-in
function Tree(treeW, frameW, rows)
  local t = { status = { treewidth = treeW, treesizable = true }, frame = { GetWidth = function() return frameW end }, buttons = {}, calls = 0 }
  for i, r in ipairs(rows) do
    local b = { shown = r.shown ~= false, xuiTextL = r.L, xuiTextR = r.R, txt = r.text or "Active Mitigation" }
    b.text = { GetText = function() return b.txt end }
    function b:IsShown() return self.shown end
    function b:GetWidth() return t.status.treewidth - SB end
    t.buttons[i] = b
  end
  function t:SetTreeWidth(w, sizable) self.calls = self.calls + 1; self.status.treewidth = w; self.status.treesizable = sizable; ns.EnsureNameRoom(self) end
  return t
end
function MinRoom(t)
  local worst
  for _, b in ipairs(t.buttons) do
    if b:IsShown() and b.xuiTextL and b.txt ~= "" then
      local r = b:GetWidth() - b.xuiTextL - (b.xuiTextR or 4)
      if not worst or r < worst then worst = r end
    end
  end
  return worst
end
''')
    L.execute(m.group(0))
    # the screenshot: a ~185 px sidebar; level 1 row starts its name at 58, level 4 at ~95; right icons (lock + note) ~41 px
    r = L.eval('''(function()
      local t = Tree(185, 1000, { { L = 58, R = 41 }, { L = 66, R = 41 }, { L = 74, R = 41 }, { L = 95, R = 41 } })
      local before = MinRoom(t)
      ns.EnsureNameRoom(t)
      return { before, MinRoom(t), t.status.treewidth, t.calls, t.status.treesizable }
    end)()''')
    check("the screenshot's case: the deepest row had %d px for its name" % r[1], r[1] < 40, r[1])
    check("after drawing, every visible row has at least 80 px for its name", r[2] >= 80, r[2])
    check("the sidebar grew by just the shortfall (185 -> %d), in one step, still resizable" % r[3], r[3] == 185 + (80 - r[1]) and r[4] == 1 and r[5] is True, (r[3], r[4]))
    r = L.eval('''(function()
      local t = Tree(320, 1000, { { L = 58, R = 41 }, { L = 95, R = 41 } })
      ns.EnsureNameRoom(t); return { t.status.treewidth, t.calls }
    end)()''')
    check("enough room already: the sidebar is not touched (never narrowed)", r[1] == 320 and r[2] == 0, r)
    r = L.eval('''(function()
      local t = Tree(185, 400, { { L = 300, R = 41 } })
      ns.EnsureNameRoom(t); return { t.status.treewidth }
    end)()''')
    check("AceGUI's limit holds: a 400 px window lets the sidebar reach 350 at most", r[1] == 350, r[1])
    r = L.eval('''(function()
      local t = Tree(185, 1000, { { L = 40, R = 41 }, { L = 150, R = 41, shown = false }, { L = 150, R = 41, text = "" } })   -- the shown row has 163 - 40 - 41 = 82 px
      ns.EnsureNameRoom(t); return { t.status.treewidth, t.calls }
    end)()''')
    check("hidden rows and rows without a name do not widen the sidebar", r[1] == 185 and r[2] == 0, r)
    r = L.eval('''(function()
      local t = Tree(185, 1000, { { L = 95, R = 41 } }); t.buttons[1].xuiTextL = nil
      ns.EnsureNameRoom(t); return { t.status.treewidth }
    end)()''')
    check("a row that recorded no inset (a reused button before decoration) is ignored", r[1] == 185, r[1])
    # Xaya 2026-11-04: "clicking tabs force-resizes the left and right panes". Every tab click rebuilds the tree; a rebuilt tree is set
    # to AceGUI's default 175 px first, so its rows can still measure that old width while the saved width is wide. The rows below
    # report a stale 153 px (175 - 22) whatever the tree's width: the sidebar must not grow on each rebuild.
    r = L.eval('''(function()
      local t = Tree(300, 1000, { { L = 58, R = 41 }, { L = 95, R = 41 } })
      for _, b in ipairs(t.buttons) do function b:GetWidth() return 175 - SB end end
      local w = {}
      for i = 1, 5 do ns.EnsureNameRoom(t); w[i] = t.status.treewidth end   -- five rebuilds (tab clicks)
      return { w[1], w[5], t.calls }
    end)()''')
    check("stale row widths after a rebuild: a sidebar that already fits its names is left alone (300 stays 300, 5 rebuilds)", r[1] == 300 and r[2] == 300 and r[3] == 0, r)
    r = L.eval('''(function()
      local t = Tree(185, 1000, { { L = 95, R = 41 } })
      for _, b in ipairs(t.buttons) do function b:GetWidth() return 175 - SB end end
      local w = {}
      for i = 1, 5 do ns.EnsureNameRoom(t); w[i] = t.status.treewidth end
      return { w[1], w[5], t.calls }
    end)()''')
    check("stale row widths: a narrow sidebar widens once to what its names need (95 + 41 + 80 + 22 = 238), not again on each rebuild",
          r[1] == 238 and r[2] == 238 and r[3] == 1, r)
    r = L.eval('''(function()
      local t = Tree(185, 1000, { { L = 95, R = 41 } }); t.status.xuiManualWidth = true
      ns.EnsureNameRoom(t); return { t.status.treewidth, t.calls }
    end)()''')
    check("a sidebar the user dragged keeps their width (names show in full on mouse-over)", r[1] == 185 and r[2] == 0, r)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
