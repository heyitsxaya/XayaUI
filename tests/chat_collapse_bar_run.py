# Collapse with the Chat Bar above the chat (XayaUI_Chat 0.6.22; REQUEST-LOG UI-20).
# Xaya 2026-11-06 (screenshot: the bar above the chat, its collapse arrow circled, tooltip "Hide the chat"): "pressing the collapse
# button should collapse the chat data bar down, not pull the chat up to it".
# Checks what the player sees, in the stand-in world (tests/chat_world.lua, real anchor geometry; not the game):
#   bar above the chat: shown, the bar at the block's top; collapsed, the bar at the block's bottom edge (where the chat's bottom was),
#   the block itself not moved; shown again, the bar back on top; bar below the chat: unchanged (bottom either way).
# Negative control (V1): the "collapsed: bar at the bottom" check fails on Chat 0.6.21 (the bar stayed at the top).
# Run: python3 tests/chat_collapse_bar_run.py   Needs: pip install lupa.
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
  local s = ns.chat2
  s.barOn, s.barSide, s.collapsed = true, "TOP", false
  C.Layout()
  local function rect(o) return W.rect(o) end
  local cont0 = rect(C.Container())
  local out = {}
  local b = rect(C.Bar())
  out.openTop = math.abs((b.b + b.h) - (cont0.b + cont0.h)) < 0.01
  C.SetCollapsed(true)
  local cont1 = rect(C.Container()); b = rect(C.Bar())
  out.collBottom = math.abs(b.b - cont1.b) < 0.01
  out.notMoved = cont1.l == cont0.l and cont1.b == cont0.b and cont1.w == cont0.w and cont1.h == cont0.h
  out.collB, out.contB = b.b, cont1.b
  C.SetCollapsed(false)
  b = rect(C.Bar()); local cont2 = rect(C.Container())
  out.backTop = math.abs((b.b + b.h) - (cont2.b + cont2.h)) < 0.01
  s.barSide = "BOTTOM"; C.Layout()
  b = rect(C.Bar()); local c3 = rect(C.Container())
  local okOpen = math.abs(b.b - c3.b) < 0.01
  C.SetCollapsed(true); b = rect(C.Bar()); c3 = rect(C.Container())
  out.belowSame = okOpen and math.abs(b.b - c3.b) < 0.01
  C.SetCollapsed(false)
  return out
end''')(W, ns, C)
check("bar above the chat, chat shown: the bar at the block's top (guard)", r.openTop)
check("collapsed: the bar drops to the block's bottom edge, where the chat's bottom was", r.collBottom, (r.collB, r.contB))
check("  ...the block does not move or change size (guard)", r.notMoved)
check("shown again: the bar back at the top (guard)", r.backTop)
check("bar below the chat: at the bottom, shown or collapsed (guard)", r.belowSame)
check("no module errors (guard)", len(list(C.errors.keys())) == 0, dict(C.errors))
print("FAILS: %d" % fails)
