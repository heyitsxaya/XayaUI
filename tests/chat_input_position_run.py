# Where the chat's input line sits (XayaUI_Chat 0.6.33; REQUEST-LOG UI-15 / UI-17 / A16 CR-7).
# Xaya 2026-11-06: "include an option where to put place the chat entry field (top or bottom; disconnected from pane (free move))";
# free move: "2 but configurable in mover gui, not from console line" (drag + its own width, set in the mover only); Top: "Both supported".
# Checks in the stand-in world (tests/chat_world.lua; not the game):
#   - Blizzard UI Reskin > Chat Panel > Layout has "Input line": Bottom, Top under the tabs, Top above the tabs, Free move (a skin setting:
#     not on QoL > Improved Chat); no slider or command sets the free place or width
#   - Bottom: as before (guard); Top under the tabs: tabs, input line, then text; Top above the tabs: input line, tabs, then text;
#     Blizzard's edit box always takes the input line's place
#   - Free move: at its own place and width, the text runs to the pane's bottom; the mover shows a box over the line; dragging it moves the
#     line and saves the place, its right edge sets the width; the privacy cover also covers it
# Negative control (V1): every check except the guards fails on Chat 0.6.32 (b84322a): 11 of 16.
# Run: python3 tests/chat_input_position_run.py   Needs: pip install lupa.
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
  local function find(t, key) for k, v in pairs(t.args or {}) do if k == key then return v end; if type(v) == "table" and v.type == "group" then local x = find(v, key); if x then return x end end end end
  local opt = find(ns.BuildChatTab(function() end), "inPos")
  out.opt = opt and table.concat(opt.sorting, ",") or ""
  out.optNames = opt and (opt.values.BOTTOM .. "|" .. opt.values.TOP .. "|" .. opt.values.ABOVE .. "|" .. opt.values.FREE) or ""
  out.optLayout = false
  local lay = ns.BuildChatTab(function() end).args.layout
  if lay and find(lay, "inPos") then out.optLayout = true end
  out.notImproved = find(ns.BuildImprovedChatTab(function() end), "inPos") == nil
  local noFreeCtl = true
  local function walk(t) for k, v in pairs(t.args or {}) do if k == "inputX" or k == "inputY" or k == "inputW" then noFreeCtl = false end; if type(v) == "table" and v.type == "group" then walk(v) end end end
  walk(W.allChatOptions())
  out.noFreeCtl = noFreeCtl
  local s = ns.chat2
  local eb = ChatFrame1EditBox
  local function R(o) local x = W.rect(o); return { l = x.l, b = x.b, w = x.w, h = x.h, t = x.b + x.h } end
  local function state()
    W.flush()
    local p, t, i, x, e = R(C.Pane()), R(C.TabsArea()), R(C.InputArea()), R(C.TextArea()), R(eb)
    return { p = p, t = t, i = i, x = x, glued = (e.l == i.l and e.b == i.b and e.w == i.w and e.h == i.h) }
  end
  if opt then opt.set(nil, "BOTTOM") else s.inputPos = "BOTTOM"; C.Refresh() end
  out.bottom = state()
  if opt then opt.set(nil, "TOP") else s.inputPos = "TOP"; C.Refresh() end
  out.top = state()
  if opt then opt.set(nil, "ABOVE") else s.inputPos = "ABOVE"; C.Refresh() end
  out.above = state()
  s.inputX, s.inputY, s.inputW = 600, 500, 300
  if opt then opt.set(nil, "FREE") else s.inputPos = "FREE"; C.Refresh() end
  out.free = state()
  -- the mover
  C.ToggleMover()
  local im = C.InputMover and C.InputMover()
  out.moverBox = im ~= nil and im:IsShown() and W.rect(im).l == W.rect(C.InputArea()).l and W.rect(im).w == W.rect(C.InputArea()).w
  if im then
    im._scripts.OnDragStart(im)
    local ia = C.InputArea(); ia:ClearAllPoints(); ia:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 650, 420); ia:SetWidth(300)
    im._scripts.OnDragStop(im); W.flush()
    out.dragSaved = (s.inputX == 650 and s.inputY == 420 and W.rect(C.InputArea()).l == 650)
    im.grip._scripts.OnMouseDown(im.grip); W.mouseX, W.mouseY = 650 + 410, 430
    im.grip._scripts.OnUpdate(im.grip, 0.02); im.grip._scripts.OnMouseUp(im.grip); W.flush()
    out.widthSaved = (s.inputW == 410 and W.rect(C.InputArea()).w == 410)
  end
  C.ToggleMover()
  out.moverGone = not (im and im:IsShown())
  -- the privacy cover over a free input line
  ns.chatDB.privOn = true; ns.ChatPrivacy_Refresh()
  local pf = _G.XayaUIChatPrivacyInput
  out.privFree = pf ~= nil and pf:IsShown() and W.rect(pf).l == W.rect(C.InputArea()).l and W.rect(pf).w == W.rect(C.InputArea()).w
  ns.chatDB.privOn = false; ns.ChatPrivacy_Refresh()
  s.inputPos = "BOTTOM"; C.Refresh(); W.flush()
  return out
end''')(W, ns, C)
check("Chat Panel > Layout has Input line: Bottom, Top under the tabs, Top above the tabs, Free move",
      r.opt == "BOTTOM,TOP,ABOVE,FREE" and r.optNames == "Bottom|Top, under the tabs|Top, above the tabs|Free move" and r.optLayout, (r.opt, r.optNames, r.optLayout))
check("  ...a look setting: not on QoL > Improved Chat (guard)", r.notImproved)
check("  ...no slider or box sets the free place or width (mover only) (guard)", r.noFreeCtl)
b = r.bottom
check("Bottom: the line at the pane's bottom, the text above it, Blizzard's edit box in it (guard)",
      abs(b.i.b - (b.p.b + 2)) < 0.01 and b.x.b > b.i.t and b.glued, (b.i.b, b.p.b, b.glued))
t = r.top
check("Top, under the tabs: the line right under the tab row", abs(t.i.t - (t.t.b - 2)) < 0.01, (t.i.t, t.t.b))
check("  ...the text under the line, down to the pane's bottom; Blizzard's edit box in the line",
      t.x.t < t.i.b and abs(t.x.b - (t.p.b + 3)) < 0.01 and t.glued, (t.x.t, t.i.b, t.x.b, t.glued))
a = r.above
check("Top, above the tabs: the line at the pane's top, the tab row under it", abs(a.i.t - (a.p.t - 2)) < 0.01 and abs(a.t.t - (a.i.b - 2)) < 0.01, (a.i.t, a.p.t, a.t.t, a.i.b))
check("  ...the text under the tabs to the pane's bottom; Blizzard's edit box in the line", a.x.t <= a.t.b and abs(a.x.b - (a.p.b + 3)) < 0.01 and a.glued)
f = r.free
check("Free move: the line at its own place and width (600, 500; 300 wide)", f.i.l == 600 and f.i.b == 500 and f.i.w == 300, (f.i.l, f.i.b, f.i.w))
check("  ...the text runs to the pane's bottom; Blizzard's edit box in the line", abs(f.x.b - (f.p.b + 3)) < 0.01 and f.glued)
check("  ...the mover shows a box over the input line", r.moverBox)
check("  ...dragging the box moves the line and saves its place", r.dragSaved)
check("  ...dragging the box's right edge sets and saves its width", r.widthSaved)
check("  ...the box goes when the mover closes (guard)", r.moverGone)
check("  ...the privacy cover also covers the moved line", r.privFree)
check("no module errors (guard)", len(list(C.errors.keys())) == 0, dict(C.errors))
print("FAILS: %d" % fails)
