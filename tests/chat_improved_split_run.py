# Chat settings split into the look and how chat behaves (XayaUI_Chat 0.6.32; REQUEST-LOG UI-18 / UI-19 / UI-21).
# Xaya 2026-11-06: "chat reskin (colors, boxes, fonting go to blizzard UI reskin. other functionality (whispers, history, filtering, etc
# -- anything newly added by the addon) go to "Improved Chat" in QoL"; rule: purely visual = Blizzard UI Reskin > Chat Panel, anything
# that changes how chat behaves = QoL > Improved Chat; her answer "1": two independent switches, and "note in improved chat that it likely
# displays better with a chat reskin (should support other chat reskin options)"; her item list, "Yes, as listed".
# Checks in the stand-in world (tests/chat_world.lua; not the game):
#   - QoL > Improved Chat is a settings page of its own with its own tick box and her note; the Chat Panel page holds no behaviour control
#   - Chat Panel OFF, Improved Chat ON: Blizzard's chat stays where the game put it; the block (Chat Data Panel, privacy button) lies around
#     it; the repeat filter and the history still work
#   - Chat Panel ON, Improved Chat OFF: the chat is still restyled and placed; no Chat Data Panel, slow-scrolling bar, collapse arrow,
#     history button, privacy button, fade driver; the filter and the history do nothing
# Negative control (V1): every check except the guards fails on Chat 0.6.31 (9f0ed8b).
# Run: python3 tests/chat_improved_split_run.py   Needs: pip install lupa.
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
  -- the pages ----------------------------------------------------------------------------------------------------------------------
  out.hasPage = type(ns.BuildImprovedChatTab) == "function"
  local ip = out.hasPage and ns.BuildImprovedChatTab(function() end) or nil
  out.ipName = ip and ip.name
  out.ipSwitch = ip and ip.xuiSwitch and ip.xuiSwitch.name
  out.ipNote = ip and ip.args.reskinNote and ip.args.reskinNote.name or ""
  local opened
  local realOpen = ns.OpenSettingsPage
  ns.OpenSettingsPage = function(...) opened = table.concat({ ... }, ">") end
  C.OpenSettings("improved"); out.openImproved = opened
  C.OpenSettings("sounds"); out.openSounds = opened
  C.OpenSettings("layout"); out.openLayout = opened
  ns.OpenSettingsPage = realOpen
  -- no behaviour control on the Chat Panel page
  local skin = ns.BuildChatTab(function() end)
  local behaviour = { scrollSpeed = 1, fade = 1, collapse = 1, on = 1, rep = 1, links = 1, histBtn = 1, whisperSelect = 1, timestamps = 1, wAdd = 1 }
  local found = {}
  local function walk(t) for k, v in pairs(t.args or {}) do if behaviour[k] then found[#found + 1] = k end; if type(v) == "table" and v.type == "group" then walk(v) end end end
  walk(skin)
  out.skinBehaviour = table.concat(found, ",")

  -- Chat Panel OFF, Improved Chat ON ------------------------------------------------------------------------------------------------
  local s = ns.chat2
  s.barOn, s.barSide, s.collapsed, s.histOn, s.spamRepeat = true, "BOTTOM", false, true, true
  local cf = C.Main()
  s.enabled = false; C.Refresh(); W.flush(); W.update(0.4, 2)
  local cr, pane, bar = W.rect(cf), W.rect(C.Pane()), C.Bar() and W.rect(C.Bar())
  out.A = { cf = { cr.l, cr.b, cr.w, cr.h }, paneL = pane.l, paneW = pane.w, paneT = pane.b + pane.h,
    barShown = C.Bar() ~= nil and C.Bar():IsShown() and C.Container():IsShown(), barTopToPaneBottom = bar and (pane.b - (bar.b + bar.h)) or -1,
    priv = _G.XayaUIChatPrivacyButton ~= nil and _G.XayaUIChatPrivacyButton:IsShown() }
  local f1 = C.Filter(nil, "CHAT_MSG_SAY", "split test line", "Bob-Realm", "", "", "", "", 0, 0, "", 0, 7001)
  local f2 = C.Filter(nil, "CHAT_MSG_SAY", "split test line", "Bob-Realm", "", "", "", "", 0, 0, "", 0, 7002)
  out.A.filter = (f1 == false and f2 == true)
  -- Chat Panel ON, Improved Chat OFF ------------------------------------------------------------------------------------------------
  s.enabled = true; s.improvedOn = false; s.fadeOn = true; C.Refresh(); W.flush(); W.update(0.4, 2)
  local tr = W.rect(C.TextArea())
  cr = W.rect(cf)
  local onUpd = 0
  for i = W.coreObjects + 1, #W.objects() do local o = W.objects()[i]; if o._scripts and o._scripts.OnUpdate then onUpd = onUpd + 1 end end
  local g1 = C.Filter(nil, "CHAT_MSG_SAY", "split test two", "Bob-Realm", "", "", "", "", 0, 0, "", 0, 7003)
  local g2 = C.Filter(nil, "CHAT_MSG_SAY", "split test two", "Bob-Realm", "", "", "", "", 0, 0, "", 0, 7004)
  out.B = { glued = (cr.l == tr.l and cr.w == tr.w and cr.h == tr.h),
    bar = C.Bar() ~= nil and C.Bar():IsShown(), scroll = C.ScrollBar() ~= nil and C.ScrollBar():IsShown(),
    arrow = _G.XayaUIChatArrow ~= nil and _G.XayaUIChatArrow:IsShown(),
    hist = _G.XayaUIChatHistoryButton ~= nil and _G.XayaUIChatHistoryButton:IsShown(),
    priv = _G.XayaUIChatPrivacyButton ~= nil and _G.XayaUIChatPrivacyButton:IsShown(),
    fade = C.on.fade and true or false, filter = (g1 == false and g2 == false), onUpd = onUpd }
  s.improvedOn = true; s.fadeOn = false; C.Refresh(); W.flush()
  return out
end''')(W, ns, C)
check("QoL > Improved Chat is a settings page of its own", r.hasPage and r.ipName == "Improved Chat", r.ipName)
check("  ...with its own tick box on its row (two independent switches, her answer \"1\")", r.ipSwitch == "Improved Chat", r.ipSwitch)
check("  ...and her note: likely displays better with a chat reskin, works with other chat reskins",
      "likely displays better with a chat reskin" in str(r.ipNote) and "other chat reskins" in str(r.ipNote), r.ipNote)
check("  ...its address is QoL > Improved Chat; Sounds opens there, Layout stays on Blizzard UI Reskin > Chat Panel",
      r.openImproved == "qol>improvedchat" and r.openSounds == "qol>improvedchat>sounds" and r.openLayout == "reskin>chatpanel>layout",
      (r.openImproved, r.openSounds, r.openLayout))
check("the Chat Panel page holds no behaviour control (scroll speed, fade, collapse, filters, links, history, whisper switch, timestamps, sounds)",
      r.skinBehaviour == "", r.skinBehaviour)
A = r.A
check("Chat Panel off, Improved Chat on: Blizzard's chat stays where the game put it", A and list(A.cf.values()) == [30, 40, 430, 120], list(A.cf.values()) if A else None)
check("  ...the block lies over it: as wide as its window, up to the top of its tab row", A and A.paneL == 30 and A.paneW == 430 and int(A.paneT) == 196, (A.paneL, A.paneW, A.paneT) if A else None)
check("  ...the Chat Data Panel shows under it, 2 px gap", A and A.barShown and abs(A.barTopToPaneBottom - 2) < 0.01, (A.barShown, A.barTopToPaneBottom) if A else None)
check("  ...the privacy button shows", A and A.priv)
check("  ...the repeat filter works (a repeat is hidden)", A and A.filter)
B = r.B
check("Chat Panel on, Improved Chat off: the chat is still restyled and placed in the pane (guard)", B and B.glued)
check("  ...no Chat Data Panel, slow-scrolling bar or collapse arrow", B and not B.bar and not B.scroll and not B.arrow, (B.bar, B.scroll, B.arrow) if B else None)
check("  ...no history button and no privacy button", B and not B.hist and not B.priv, (B.hist, B.priv) if B else None)
check("  ...the fade driver does not run even with Fade saved on", B and not B.fade)
check("  ...the repeat filter does nothing (a repeat shows)", B and B.filter)
check("  ...one OnUpdate left: the Chat Panel's own upkeep", B and B.onUpd == 1, B.onUpd if B else None)
check("no module errors (guard)", len(list(C.errors.keys())) == 0, dict(C.errors))
print("FAILS: %d" % fails)
