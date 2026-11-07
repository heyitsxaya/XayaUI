# Every control on the chat fades with it (REQUEST-LOG O-143; XayaUI_Chat 0.6.36). Xaya 2026-11-07: "weird chat appearance when chat fades
# -- the sidebar icons should also be fading"; her screenshot: with the chat faded out, the collapse chevron and the gold-boxed privacy eye
# stayed at full strength. Expected (hub's brief from her words): they fade and come back with the chat, and the mouse over them wakes it.
# Checks in the stand-in world (tests/chat_world.lua; not the game). Negative control (V1): every check except the guards fails on
# Chat 0.6.35 (64d8e78).
# Run: python3 tests/chat_fade_controls_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1

def world(saved):
    lua = LuaRuntime(unpack_returned_tuples=True)
    W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
    lua.execute(saved)
    lua.execute("MouseIsOver = function(f) return W_OVER and W_OVER[f] or false end")
    W.start()
    run = lua.eval("function(W, src) local f = assert(loadstring(src)); setfenv(f, setmetatable({ W = W, ns = W.ns, C = W.ns.Chat }, { __index = _G })); return f() end")
    return lua, W, (lambda src: run(W, src))

FADE = '''
local s = ns.chat2
s.fadeOn, s.fadeAfter, s.fadeTo, s.fadeSeconds, s.fadeHover = true, 2, 0, 0.1, true
C.Refresh(); W.flush()
W.mouseX, W.mouseY = 5000, 5000
W.update(0.1, 60)      -- 6 s idle: faded out
'''
# --- without the sidebar: the chevron and the eye beside the chat ---------------------------------------------------------------
lua, W, run = world("CueRulesDB.chat2 = { sbOn = false, barOn = false }")
r = run(FADE + '''
local out = { fade = C.fade, arrow = XayaUIChatArrow:GetAlpha(), eye = XayaUIChatPrivacyButton:GetAlpha(), eyeShown = XayaUIChatPrivacyButton:IsShown() }
-- the mouse over the eye wakes the chat
local e = W.rect(XayaUIChatPrivacyButton); W.mouseX, W.mouseY = e.l + 2, e.b + 2
W.update(0.1, 10)
out.woke = C.fade; out.arrowBack = XayaUIChatArrow:GetAlpha(); out.eyeBack = XayaUIChatPrivacyButton:GetAlpha()
return out
''')
check("the chat faded out (guard)", r.fade < 0.02, r.fade)
check("the collapse chevron fades with it", r.arrow < 0.02, r.arrow)
check("the privacy eye beside the chat fades with it", r.eyeShown and r.eye < 0.02, (r.eyeShown, r.eye))
check("the mouse over the eye brings the chat back", r.woke > 0.98, r.woke)
check("  ...and the chevron and the eye with it (guard)", r.arrowBack > 0.98 and r.eyeBack > 0.85, (r.arrowBack, r.eyeBack))
# --- with the sidebar (on by default): it fades with the chat by default -------------------------------------------------------
lua, W, run = world("CueRulesDB.chat2 = { }")
r = run(FADE + '''
local sb = C.Sidebar()
local out = { def = ns.chat2.sbFade, sb = sb:GetAlpha(), eyeIn = XayaUIChatPrivacyButton:GetParent() == sb }
local b = W.rect(sb); W.mouseX, W.mouseY = b.l + 3, b.b + 3
W.update(0.1, 10)
out.woke = C.fade; out.sbBack = sb:GetAlpha()
return out
''')
check("the sidebar fades with the chat by default (Fade with the chat on)", r["def"] is True and r.sb < 0.02, (r["def"], r.sb))
check("  ...its buttons (the eye) are inside it, so they fade too (guard)", r.eyeIn is True)
check("the mouse over the sidebar brings the chat and the sidebar back", r.woke > 0.98 and r.sbBack > 0.98, (r.woke, r.sbBack))
check("no module errors (guard)", len(list(run("return C.errors").keys())) == 0, dict(run("return C.errors")))
print("FAILS: %d" % fails)
