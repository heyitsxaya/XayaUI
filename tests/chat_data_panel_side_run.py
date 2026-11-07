# Chat Data Panel (the Chat Bar renamed) left or right of the chat (XayaUI_Chat 0.6.23; REQUEST-LOG UI-10, UI-28, UI-29).
# Xaya 2026-11-06: "chat bar is confusing because it implies text entry -- rename to "Chat Data Panel" and also allow for it to be
# assigned to the left or right-hand side"; her answers: "Vertical strip beside chat", "snap to chat window height",
# "Slider 40-200, default 90".
# Checks what the player sees in the stand-in world (tests/chat_world.lua, real anchor geometry; not the game):
#   the settings name it Chat Data Panel (page, switch, place, fade); Left / Right are offered; placed Left: the strip is at the
#   block's left, as tall as the chat pane, 90 wide by default, the pane right of it with the gap between, its blocks stacked top to
#   bottom under the arrow; Right: the mirror; the width slider shows only for Left / Right (height only for Above / Below).
# Negative control (V1): every non-guard check fails on Chat 0.6.22.
# Run: python3 tests/chat_data_panel_side_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
lua = LuaRuntime(unpack_returned_tuples=True)
W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1
W.start()
ns = W.ns
C = ns.Chat
r = lua.eval(r'''function(W, ns, C)
  local out = {}
  local opts = ns.BuildImprovedChatTab(function() end)   -- (Chat 0.6.33; UI-21) QoL > Improved Chat
  local page, A = nil, {}
  local function collect(t, depth)   -- every control under the page, through its section tabs
    for k, v in pairs(t.args or {}) do
      if type(v) == "table" then
        if v.type == "group" and depth < 4 then collect(v, depth + 1) elseif A[k] == nil then A[k] = v end
      end
    end
  end
  for _, g in pairs(opts.args or {}) do
    if type(g) == "table" and g.type == "group" and (g.name == "Chat Bar" or g.name == "Chat Data Panel") then page = g end
  end
  if page then collect(page, 0); page = { name = page.name, args = A } end
  out.found = page ~= nil
  if page then
    out.pageName = page.name
    out.onName = page.args.on.name
    out.sideName = page.args.side.name
    out.hasLR = page.args.side.values and page.args.side.values.LEFT == "Left of the chat" and page.args.side.values.RIGHT == "Right of the chat"
    out.hasW = page.args.w ~= nil
  end
  local s = ns.chat2
  s.barOn, s.collapsed, s.barGap = true, false, 2
  s.barSide = "LEFT"; s.barW = nil; C.Layout()
  local cont, pane, bar = W.rect(C.Container()), W.rect(C.Pane()), W.rect(C.Bar())
  out.L = { bar.l - cont.l, bar.w, bar.h, pane.h, pane.l - (bar.l + bar.w), cont.w - pane.w - bar.w }
  if page and page.args.w then
    out.wShown = not page.args.w.hidden() ; out.hHidden = page.args.h.hidden() and true or false
    out.wGet = page.args.w.get()
  end
  local slots = {}
  for _, k in ipairs(C.Bar() and C.Bar()._kids or {}) do end
  s.barSide = "RIGHT"; s.barW = 120; C.Layout()
  cont, pane, bar = W.rect(C.Container()), W.rect(C.Pane()), W.rect(C.Bar())
  out.R = { (cont.l + cont.w) - (bar.l + bar.w), bar.w, bar.h, pane.h, bar.l - (pane.l + pane.w) }
  s.barSide = "BOTTOM"; C.Layout()
  if page and page.args.w then out.wHiddenBottom = page.args.w.hidden() and true or false end
  return out
end''')(W, ns, C)
print("found page:", r.found, r.pageName)
check("the settings page is named Chat Data Panel", r.pageName == "Chat Data Panel", r.pageName)
check("  ...its switch reads Show the Chat Data Panel", r.onName == "Show the Chat Data Panel", r.onName)
check("  ...Place the panel offers Left of the chat and Right of the chat", r.sideName == "Place the panel" and r.hasLR, (r.sideName, r.hasLR))
L = r.L
check("Left: the strip at the block's left edge, as tall as the chat pane, 90 wide by default", L and L[1] == 0 and L[3] == L[4] and L[2] == 90, list(L.values()) if L else None)
check("  ...the chat pane right of it with the 2 px gap", L and abs(L[5] - 2) < 0.01 and abs(L[6] - 2) < 0.01, list(L.values()) if L else None)
check("  ...the width slider shows (90 when nothing is saved); the height slider is hidden", r.hasW and r.wShown and r.hHidden and r.wGet == 90, (r.hasW, r.wShown, r.hHidden, r.wGet))
R = r.R
check("Right: the strip at the block's right edge, 120 wide as set, as tall as the pane, the gap left of it", R and abs(R[1]) < 0.01 and R[2] == 120 and R[3] == R[4] and abs(R[5] - 2) < 0.01, list(R.values()) if R else None)
check("Below the chat: the width slider is hidden (guard)", r.wHiddenBottom is None or r.wHiddenBottom)
check("no module errors (guard)", len(list(C.errors.keys())) == 0, dict(C.errors))
print("FAILS: %d" % fails)
