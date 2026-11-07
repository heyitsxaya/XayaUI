# Stub test for the Chat Panel (Chat/*.lua). Run from the repo root: python3 tests/chat_run.py   Needs: pip install lupa.
# Uses tests/chat_world.lua (stand-in frames with real anchor geometry). Checks logic and placement, not the real game.
import os, sys
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = package.path")
W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1
S = W.start()
check("started with chat2 table", S is not None)

L = lua.globals()
ns = W.ns
C = ns.Chat
def rect(o):
    r = W.rect(o); return (r.l, r.b, r.w, r.h)
def inside(inner, outer, tol=0.01):
    a, b = rect(inner), rect(outer)
    return a[0] >= b[0]-tol and a[1] >= b[1]-tol and a[0]+a[2] <= b[0]+b[2]+tol and a[1]+a[3] <= b[1]+b[3]+tol
def run(code, *args):
    return lua.eval("function(W, ns, C, ...) " + code + " end")(W, ns, C, *args)

check("no module errors at start", len(list(C.errors.keys())) == 0, dict(C.errors))
check("all modules applied", all(C.applied[k] for k in C.applied), list(C.applied.keys()))
cont, pane, tabsA, textA, inputA, bar = C.Container(), C.Pane(), C.TabsArea() if False else C.TabsArea(), C.TextArea(), C.InputArea(), C.Bar()
check("container exists", cont is not None)

# ---- geometry ------------------------------------------------------------------------------------------------------------
check("pane inside container", inside(pane, cont))
check("input area inside pane", inside(inputA, pane), (rect(inputA), rect(pane)))
check("text area inside pane", inside(textA, pane))
check("tabs inside pane", inside(tabsA, pane))
check("bar inside container", inside(bar, cont))
pr, br = rect(pane), rect(bar)
check("bar below pane by default (bar bottom <= pane bottom)", br[1] + br[3] <= pr[1] + 0.01, (pr, br))
check("pane is 440 wide and 230 high by default", (int(pr[2]), int(pr[3])) == (440, 230), pr)
cf1 = W.cf1
check("ChatFrame1 filled the text area", rect(cf1) == rect(textA), (rect(cf1), rect(textA)))
eb = L.ChatFrame1EditBox
check("edit box sits inside the input area", rect(eb) == rect(inputA), (rect(eb), rect(inputA)))
check("edit box inside the pane", inside(eb, pane))
check("ChatFrame2's edit box (docked) inside input area too", rect(L.ChatFrame2EditBox) == rect(inputA))
check("floating ChatFrame3 left alone", rect(W.cf3)[0] == 900, rect(W.cf3))
dr_, tr_ = rect(L.GeneralDockManager), rect(tabsA)
check("dock manager on the tab strip, stopping 22 px short of its right end for the history button",
      dr_[0] == tr_[0] and dr_[1] == tr_[1] and dr_[3] == tr_[3] and abs((dr_[0] + dr_[2]) - (tr_[0] + tr_[2] - 22)) < 0.01, (dr_, tr_))
# ---- history button vs scroll bar and tabs (Xaya 2026-11-04: "chat history icon still clips over sidebar") ------------------------
def overlap(a, b):
    ra, rb = rect(a), rect(b)
    return ra[0] < rb[0] + rb[2] - 0.01 and rb[0] < ra[0] + ra[2] - 0.01 and ra[1] < rb[1] + rb[3] - 0.01 and rb[1] < ra[1] + ra[3] - 0.01
hb, sb = L.XayaUIChatHistoryButton, L.XayaUIChatScrollBar
check("history button exists and is shown by default", hb is not None and hb.IsShown(hb) is True)
check("history button inside the pane and inside the tab row", inside(hb, pane) and inside(hb, tabsA), (rect(hb), rect(tabsA)))
check("history button does not cover the Chat Panel's scroll bar (its up arrow)", sb is not None and not overlap(hb, sb), (rect(hb), rect(sb)))
check("history button does not sit on the tabs (the dock stops short of it)", not overlap(hb, L.GeneralDockManager), (rect(hb), rect(L.GeneralDockManager)))
run("ns.chat2.histButton = false; C.Refresh()")
check("history button off: the tabs use the whole tab row", rect(L.GeneralDockManager) == rect(tabsA), (rect(L.GeneralDockManager), rect(tabsA)))
run("ns.chat2.histButton = true; ns.chat2.tabsShow = false; C.Refresh()")
check("tab row hidden: history button in the text area's corner, still off the scroll bar",
      inside(hb, textA) and not overlap(hb, sb), (rect(hb), rect(textA), rect(sb)))
run("ns.chat2.tabsShow = true; C.Refresh()")
check("tab row back: history button back at the row's end", inside(hb, tabsA) and not overlap(hb, sb), (rect(hb), rect(tabsA)))
# ---- tabs laid out again for the width they get (Xaya 2026-11-04: "user-created chat tabs should not have their boxes overflow") --
run("""W.layoutCalls = {}
FCFDock_UpdateTabs = function(dock, force) W.layoutCalls[#W.layoutCalls + 1] = { w = dock:GetWidth(), force = force } end
C.dockLaidOutW, C.dockLaidOutAt = nil, nil; W.now = (W.now or 0) + 5; C.Layout()""")
calls = lua.eval("function(W) return W.layoutCalls end")(W)
first = calls[1] if calls else None
check("the game lays the tabs out again (forced) once the dock sits in the tab row, at the dock's new width",
      first is not None and first.force is True and abs(first.w - rect(L.GeneralDockManager)[2]) < 0.01, (first and first.w, rect(L.GeneralDockManager)))
n0 = len(list(calls.keys()))
run("C.Layout(); C.Anchor()")
check("same width again: not laid out again", len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys())) == n0)
run("W.now = W.now + 2; ns.chat2.width = 380; C.Layout()")
calls = lua.eval("function(W) return W.layoutCalls end")(W)
lastc = calls[len(list(calls.keys()))]
check("pane narrower: the tabs are laid out again at the narrower width", len(list(calls.keys())) == n0 + 1 and abs(lastc.w - rect(L.GeneralDockManager)[2]) < 0.01,
      (len(list(calls.keys())), lastc.w, rect(L.GeneralDockManager)))
run("W.now = W.now + 2; W.combat = true; InCombatLockdown = function() return W.combat end; ns.chat2.width = 400; C.Layout()")
check("in combat: the tabs are not laid out (the next layout out of combat does it)", len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys())) == n0 + 1)
run("W.combat = false; C.Layout()")
check("after combat: laid out at the new width", len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys())) == n0 + 2)
# never on every re-anchor (a re-run resets Blizzard's tab alpha: it would look like blinking tabs)
run("W.now = W.now + 2; ns.chat2.width = 401; C.Layout()")
nA = len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys()))
run("ns.chat2.width = 402; C.Layout(); ns.chat2.width = 403; C.Layout(); ns.chat2.width = 404; C.Layout()")
check("several width changes within one second: laid out at most once in that second",
      len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys())) == nA, (nA, len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys()))))
run("W.now = W.now + 1.5; C.Layout()")
check("a second later: laid out once for the latest width", len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys())) == nA + 1)
run("W.now = W.now + 2; GeneralDockManager._wobble = 0.3; C.Layout(); W.now = W.now + 2; GeneralDockManager._wobble = -0.2; C.Layout(); GeneralDockManager._wobble = nil")
check("a width that wobbles by a fraction of a pixel never lays out again",
      len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys())) == nA + 1, len(list(lua.eval("function(W) return W.layoutCalls end")(W).keys())))
run("ns.chat2.width = 440; C.Layout(); FCFDock_UpdateTabs = nil")
# ---- text gutter (Xaya 2026-11-04: "create a small gutter of 2-3px for easier legibility") ---------------------------------------
run("ns.chat2.textInset = 0; C.Layout()")
check("text inset 0 saved: the text still starts 2 px in from the pane's edge", abs(rect(textA)[0] - rect(pane)[0] - 2) < 0.01, (rect(textA), rect(pane)))
check("and the chat window follows the text area", rect(cf1)[0] == rect(textA)[0], (rect(cf1), rect(textA)))
run("ns.chat2.textInset = 6; C.Layout()")
check("default inset 6: text 6 px in", abs(rect(textA)[0] - rect(pane)[0] - 6) < 0.01, (rect(textA), rect(pane)))
check("Blizzard side strip hidden", L.ChatFrame1ButtonFrame.IsShown(L.ChatFrame1ButtonFrame) is False)
check("social button hidden by default", L.QuickJoinToastButton.IsShown(L.QuickJoinToastButton) is False)

# ---- bar on top -----------------------------------------------------------------------------------------------------------
run("ns.chat2.barSide='TOP'; C.Layout()")
pr, br = rect(pane), rect(bar)
check("bar above pane when barSide=TOP", br[1] >= pr[1] + pr[3] - 0.01, (pr, br))
check("still inside container (TOP)", inside(pane, cont) and inside(bar, cont))
check("input still inside pane (TOP)", inside(inputA, pane))
run("ns.chat2.barSide='BOTTOM'; C.Layout()")

# ---- bar off, tabs off ----------------------------------------------------------------------------------------------------
run("ns.chat2.barOn=false; C.Layout()")
check("bar hidden when off", bar.IsShown(bar) is False)
check("pane == container height with bar off", int(rect(pane)[3]) == int(rect(cont)[3]), (rect(pane), rect(cont)))
run("ns.chat2.barOn=true; ns.chat2.tabsShow=false; C.Layout()")
check("tabs hidden: dock manager suppressed", L.GeneralDockManager.IsShown(L.GeneralDockManager) is False)
check("tabs hidden: text area still inside pane", inside(textA, pane))
run("ns.chat2.tabsShow=true; C.Layout()")
check("tabs back: dock manager shown", L.GeneralDockManager.IsShown(L.GeneralDockManager) is True)

# ---- resizing -------------------------------------------------------------------------------------------------------------
run("ns.chat2.width=600; ns.chat2.height=300; C.Layout()")
check("width setting applied", int(rect(pane)[2]) == 600, rect(pane))
check("height setting applied", int(rect(pane)[3]) == 300, rect(pane))
check("chat frame follows resize", rect(cf1) == rect(textA))
run("ns.chat2.width=440; ns.chat2.height=230; C.Layout()")

# ---- collapse -------------------------------------------------------------------------------------------------------------
run("C.SetCollapsed(true)")
check("collapsed: pane hidden", pane.IsShown(pane) is False)
check("collapsed: bar still shown", bar.IsShown(bar) is True)
check("collapsed: chat frame invisible", cf1.GetAlpha(cf1) < 0.01, cf1.GetAlpha(cf1))
check("collapsed: tab invisible", L.ChatFrame1Tab.GetAlpha(L.ChatFrame1Tab) < 0.01)
check("collapsed: edit box mouse off", L.ChatFrame1EditBox.IsMouseEnabled(L.ChatFrame1EditBox) is False)
# Blizzard tries to set alpha while collapsed: our hook must keep it invisible
cf1.SetAlpha(cf1, 1)
check("collapsed: Blizzard SetAlpha(1) is overridden", cf1.GetAlpha(cf1) < 0.01, cf1.GetAlpha(cf1))
run("C.SetCollapsed(false)")
check("expanded: pane shown", pane.IsShown(pane) is True)
check("expanded: chat frame visible again", cf1.GetAlpha(cf1) > 0.99, cf1.GetAlpha(cf1))
cf1.SetAlpha(cf1, 0.5)
check("expanded: Blizzard alpha 0.5 retained", abs(cf1.GetAlpha(cf1) - 0.5) < 0.01, cf1.GetAlpha(cf1))
cf1.SetAlpha(cf1, 1)

# ---- fade -----------------------------------------------------------------------------------------------------------------
run("ns.chat2.fadeOn=true; ns.chat2.fadeAfter=2; ns.chat2.fadeTo=0; ns.chat2.fadeSeconds=0.4; C.Touch(); C.Schedule()")
W.flush()
W.mouseX, W.mouseY = -5, -5
W.update(0.2, 5)
check("fade: still opaque before the delay", pane.GetAlpha(pane) > 0.99, pane.GetAlpha(pane))
W.update(0.5, 12)
check("fade: faded after idle", pane.GetAlpha(pane) < 0.05, pane.GetAlpha(pane))
check("fade: chat frame faded too", cf1.GetAlpha(cf1) < 0.05, cf1.GetAlpha(cf1))
cr = rect(cont)
W.mouseX, W.mouseY = cr[0] + 10, cr[1] + 10
W.update(0.2, 10)
check("fade: mouse over wakes it", pane.GetAlpha(pane) > 0.95, pane.GetAlpha(pane))
W.mouseX, W.mouseY = -5, -5
# (Chat 0.6.24; REQUEST-LOG UI-11, Xaya: "mouse hover over should also allow for chat to reappear if this option is selected", her
# answer "Its own tick box") "The mouse over the chat brings it back": on by default (above); unticked, the mouse does not wake it.
# Negative control: the unticked check and the option check fail on Chat 0.6.23.
run("ns.chat2.fadeHover=false")
W.update(0.5, 12)
check("fade, hover unticked: faded again after idle", pane.GetAlpha(pane) < 0.05, pane.GetAlpha(pane))
W.mouseX, W.mouseY = cr[0] + 10, cr[1] + 10
W.update(0.2, 10)
check("fade, hover unticked: the mouse over the chat does NOT bring it back", pane.GetAlpha(pane) < 0.05, pane.GetAlpha(pane))
hov = lua.eval("function(ns) local t = ns.BuildChatTab(function() end); local found; local function f(g, d) for k, v in pairs(g.args or {}) do if k == 'hoverWake' and type(v) == 'table' and v.type == 'toggle' then found = v end; if type(v) == 'table' and v.type == 'group' and d < 5 then f(v, d + 1) end end end; f(t, 0); return found end")(W.ns)
check("fade: the option reads 'The mouse over the chat brings it back' and is ticked when nothing is saved",
      hov is not None and hov.name == "The mouse over the chat brings it back" and lua.eval("function(o, ns) ns.chat2.fadeHover = nil; return o.get() end")(hov, W.ns) == True,
      hov.name if hov is not None else None)
run("ns.chat2.fadeHover=nil")
W.mouseX, W.mouseY = -5, -5
run("ns.chat2.fadeOn=false; C.Schedule()")
W.flush(); W.update(0.2, 10)
check("fade off: opaque again", pane.GetAlpha(pane) > 0.99, pane.GetAlpha(pane))

# ---- bar content ----------------------------------------------------------------------------------------------------------
types = run("local out={} for _,t in ipairs(C.Bar_Types()) do out[#out+1]=type(t)=='table' and (t[1] or t.key) or t end return table.concat(out,',')")
check("bar types offered", "FPS" in str(types) and "TIME" in str(types) and "CUSTOM" in str(types), types)
W.update(1.1, 3)
txt = run("local t={} for _,o in ipairs({C.Bar():GetChildren()}) do t[#t+1]=tostring(o._text) end return table.concat(t,'|')")
check("bar ticker ran without error", len(list(C.errors.keys())) == 0, dict(C.errors))

# ---- spam filters ---------------------------------------------------------------------------------------------------------
F = C.Filter
def filt(ev, msg, who, line):
    return run("return C.Filter(nil, ...)", ev, msg, who, "", "", "", "", 0, 0, "", 0, line)
run("ns.chat2.spamRepeat=true; ns.chat2.spamSeconds=30; ns.chat2.spamPhrases='buy gold\\nboost run'; ns.chat2.spamWord=false")
r = filt("CHAT_MSG_SAY", "hello there", "Bob-Realm", 1001)
check("normal message passes", r is False or r == False)
r = filt("CHAT_MSG_SAY", "hello there", "Bob-Realm", 1002)
check("repeat within window is suppressed", r is True)
r = filt("CHAT_MSG_SAY", "hello there", "Alice-Realm", 1003)
check("same text from someone else passes", r is False)
r = filt("CHAT_MSG_SAY", "BUY GOLD now", "Cy-R", 1004)
check("blocked phrase suppressed (case-insensitive)", r is True)
r = filt("CHAT_MSG_CHANNEL", "LFG boost run 12", "Dee-R", 1005)
check("second phrase in list suppressed", r is True)
r = filt("CHAT_MSG_GUILD", "buy gold", "Eve-R", 1006)
check("guild chat is never filtered", r is False)
r = filt("CHAT_MSG_SAY", "hello there", "Bob-Realm", 1002)
check("same lineID gets the same verdict (second window)", r is True)
r = filt("CHAT_MSG_SAY", "buy gold", "Xaya", 1007)
check("own messages never filtered", r is False)
run("ns.chat2.spamWord=true")
r = filt("CHAT_MSG_SAY", "he is a boosted warrior", "Fay-R", 1008)
check("whole-word mode: 'boost run' not in 'boosted warrior'", r is False)
# audit D37 (Chat 0.6.32): punctuation at a phrase's edge and non-Latin letters (helper checked directly: no filter cache involved)
ww = lambda text, ph: run("return ns.Chat_WholeWord and ns.Chat_WholeWord(...)", text, ph)
check("D37 whole words: 'wts!' found in 'wts! cheap'", ww("wts! cheap", "wts!") is True)
check("D37 whole words: '$gold' found in 'only $gold here'", ww("only $gold here", "$gold") is True)
check("D37 whole words: Cyrillic phrase found as a word", ww("\u043f\u0440\u043e\u0434\u0430\u043c \u0437\u043e\u043b\u043e\u0442\u043e".encode().decode("unicode_escape"), "\u0437\u043e\u043b\u043e\u0442\u043e".encode().decode("unicode_escape")) is True)
check("D37 whole words: Cyrillic phrase not found inside a longer word", ww("\u0437\u043e\u043b\u043e\u0442\u043e\u0439".encode().decode("unicode_escape"), "\u0437\u043e\u043b\u043e\u0442\u043e".encode().decode("unicode_escape")) is False)
check("D37 whole words: 'gold' still not inside 'golden'", ww("golden rings", "gold") is False)
check("D37 whole words: 'gold' found later after a non-match", ww("golden gold", "gold") is True)
run("ns.chat2.spamPhrases='buy gold\\nboost run\\nwts!'")
r = filt("CHAT_MSG_SAY", "wts! cheap stuff", "Sp-Realm", 9101)
check("D37 through the chat filter: 'wts!' hides 'wts! cheap stuff' in whole-word mode", r is True, r)
run("ns.chat2.spamPhrases='buy gold\\nboost run'")
run("ns.chat2.spamWord=false")

# secret safety: a protected message must pass untouched; a protected author must not break the filters, history or sounds
SEC = "<<secret>>"
r = filt("CHAT_MSG_SAY", SEC, "Lee-R", 1100)
check("secret message passes untouched", r is False)
r = filt("CHAT_MSG_SAY", "hello world 2", SEC, 1101)
check("secret author does not error", r is False)
W.now += 1
W.fireEvent("CHAT_MSG_SAY", SEC, SEC)
check("secret message/author through every handler leaves no errors", len(list(C.errors.keys())) == 0)
check("secret lines are counted, not read", C.stats.protected >= 1, C.stats.protected)
lines = run("return table.concat(C.History_Lines(), '\\n')")
check("history shows protected lines as a placeholder", "[protected message]" in str(lines) and SEC not in str(lines), lines)

# ---- links ----------------------------------------------------------------------------------------------------------------
out = run("return C.Linkify(ns.chat2, 'go to https://example.com/a?b=1 now')")
check("link wrapped as addon hyperlink", "|Haddon:XayaUI:url:" in str(out), out)
check("link keeps visible text", "https://example.com/a?b=1" in str(out), out)
out2 = run("return C.Linkify(ns.chat2, 'plain text no links')")
check("no link, no change", out2 == "plain text no links")
out3 = run("return C.Linkify(ns.chat2, '|cff0070dd|Hitem:123|h[Sword]|h|r see www.site.org/x')")
check("item link untouched and www link wrapped", "|Hitem:123|h[Sword]|h" in str(out3) and "|Haddon:XayaUI:url:" in str(out3), out3)
r = filt("CHAT_MSG_SAY", "see https://example.com now", "Gus-R", 1009)
check("filter returns rewritten message", isinstance(r, tuple) and r[0] is False and "|Haddon:XayaUI" in str(r[1]), r)
check("filter keeps trailing args (lineID) when rewriting", len(r) == 12 and r[-1] == 1009, r)
# clicking
lid = str(out).split("url:")[1].split("|")[0]
run("_G.SetItemRef('addon:XayaUI:url:" + lid + "', 'x', 'LeftButton')")
box = L.XayaUIChatCopy
check("clicking the link opens the copy box with the URL", box is not None and "example.com" in str(box.edit._text), box.edit._text if box else None)
# ctrl + right click ignore
W.ctrl = True
run("ns.chat2.ignoreClick=true; _G.SetItemRef('player:Spammer-Realm', 'x', 'RightButton')")
check("ctrl+right-click ignores the player", "Spammer-Realm" in [str(x) for x in W.ignored.values()], list(W.ignored.values()))
run("_G.SetItemRef('player:Xaya', 'x', 'RightButton')")
check("never ignores yourself", len(list(W.ignored.values())) == 1)
# audit D32 (Chat 0.6.32): "Ignoring" only when the game added them; a full list / an already ignored name says it did not work
for k in list(W.printed.keys()): W.printed[k] = None
W.ignoreFull = True
run("_G.SetItemRef('player:Third-Realm', 'x', 'RightButton')")
W.ignoreFull = False
out = " ".join(str(v) for v in W.printed.values() if v)
check("D32 Ignore list full: says it could not ignore, not 'Ignoring'", "Could not ignore" in out and "Ignoring Third" not in out, out[:200])
for k in list(W.printed.keys()): W.printed[k] = None
run("_G.SetItemRef('player:Spammer-Realm', 'x', 'RightButton')")
out = " ".join(str(v) for v in W.printed.values() if v)
check("D32 already ignored: says it could not ignore", "Could not ignore" in out, out[:200])
W.ctrl = False
# (Chat 0.6.25; REQUEST-LOG UI-12 / UI-17: "allow a modifier selector (alt, ctrl. fn(?))"; her answer "detect available modifiers
# based on available keybinds not already assigned; also allow user to record and save their own keybind")
# Stand-in game: Alt / Shift / Meta keys and C_KeyBindings.GetBindingByKey (ALT-BUTTON2 bound to a stand-in action). Negative control:
# every check below fails on Chat 0.6.24 except those marked (guard).
run("""_G.IsAltKeyDown = function() return W.alt and true or false end
_G.IsShiftKeyDown = function() return W.shift and true or false end
_G.IsMetaKeyDown = function() return false end
_G.IsMacClient = function() return false end
_G.C_KeyBindings = { GetBindingByKey = function(k) if k == 'ALT-BUTTON2' then return 'STANDIN_ACTION' end return '' end }""".replace("W.alt", "W_alt").replace("W.shift", "W_shift"))
free = lua.eval("function(C) return table.concat(C.FreeCombos and C.FreeCombos() or {}, ',') end")(C)
check("the picker lists the right-clicks with no key binding: Ctrl, Shift and the pairs, not Alt (bound in the stand-in)",
      free == "ALT-CTRL-BUTTON2,ALT-SHIFT-BUTTON2,CTRL-BUTTON2,CTRL-SHIFT-BUTTON2,SHIFT-BUTTON2", free)
names = lua.eval("function(C) return C.ComboName('ALT-CTRL-BUTTON2') .. ' / ' .. C.ComboName('SHIFT-BUTTON1') end")(C)
check("  ...named for the player: 'Alt + Ctrl + right-click', 'Shift + left-click'", names == "Alt + Ctrl + right-click / Shift + left-click", names)
run("ns.chat2.ignoreCombo = 'SHIFT-BUTTON2'")
n0 = len(list(W.ignored.values()))
run("_G.W_shift = false; W.ctrl = true; _G.SetItemRef('player:Other-Realm', 'x', 'RightButton'); W.ctrl = false")
check("with Shift + right-click chosen, Ctrl + right-click no longer ignores", len(list(W.ignored.values())) == n0)
run("_G.W_shift = true; _G.SetItemRef('player:Other-Realm', 'x', 'RightButton'); _G.W_shift = false")
check("  ...Shift + right-click does", "Other-Realm" in [str(x) for x in W.ignored.values()], list(W.ignored.values()))
# the recorder: a plain click is refused; Alt + middle-click is saved (and said to be unbound)
run("ns.chat2.ignoreCombo = nil; C.RecordCombo(function() end)")
rec = L.XayaUIChatCopy and L.XayaUIChatComboRecorder
rec = L.XayaUIChatComboRecorder
run("local r = _G.XayaUIChatComboRecorder; r._scripts.OnClick(r, 'LeftButton')")
check("recorder: a plain click is refused (nothing saved)", lua.eval("function(ns) return ns.chat2.ignoreCombo end")(ns) is None)
run("_G.W_alt = true; local r = _G.XayaUIChatComboRecorder; r._scripts.OnClick(r, 'MiddleButton'); _G.W_alt = false")
check("recorder: Alt + middle-click is saved", lua.eval("function(ns) return ns.chat2.ignoreCombo end")(ns) == "ALT-BUTTON3")
check("recorder: Ctrl + right-click stays the choice when nothing is saved (guard)", lua.eval("function(C, ns) ns.chat2.ignoreCombo = nil; return C.IgnoreCombo() end")(C, ns) == "CTRL-BUTTON2")
run("ns.chat2.ignoreCombo = nil")

# ---- history --------------------------------------------------------------------------------------------------------------
before = C.History_Count()
n = run("return #C.MSG_EVENTS")
check("message events registered", n >= 10, n)
W.now += 1
W.fireEvent("CHAT_MSG_SAY", "hi from the test", "Hal-Realm")
W.fireEvent("CHAT_MSG_PARTY", "party line", "Ida-Realm")
W.fireEvent("CHAT_MSG_CHANNEL", "WTS boost spam", "Spam-Realm", "", "2. Trade - City", "", "", 0, 2, "Trade")
check("history count after three messages", C.History_Count() == before + 3, (before, C.History_Count()))
check("plain text strips colors and links", C.Plain("|cffff0000|Hitem:1|h[Sword]|h|r ok") == "[Sword] ok", C.Plain("|cffff0000|Hitem:1|h[Sword]|h|r ok"))
pl = C.Plain("|cnIQ4:|Hitem:123|h[Primeval Skyfriend]|h|r and |Kg1|k name")
check("named colors (|cnNAME:) and name codes are stripped", "|cn" not in pl and "IQ4:" not in pl and "|K" not in pl and "[Primeval Skyfriend]" in pl, pl)
C.History_Toggle()
hf = L.XayaUIChatHistory
check("history frame built and shown", hf is not None and hf.IsShown(hf))
labels = run("local t={} for _,b in ipairs(W.cf1 and {} or {}) do end local f=_G.XayaUIChatHistory local out={} for _,b in ipairs(f.kb) do if b:IsShown() then out[#out+1]=b.t._text end end return table.concat(out,',')")
check("[Chat 0.6.15] a button per tab, then Console, All last: General, Combat Log, Trade, Console, All", str(labels) == "General,Combat Log,Trade,Console,All", labels)
def lines(): return str(run("return table.concat(C.History_Lines(), '\\n')"))
check("[Chat 0.6.15] the window opens on the chat tab you are on (General), not All", "hi from the test" in lines() and "party line" not in lines(), lines())
run("C.History_Select(1)")
check("filter by tab: General shows the say line only", "hi from the test" in lines() and "party line" not in lines() and "boost spam" not in lines(), lines())
run("C.History_Select(2)")
check("filter by tab: tab 2 shows the party line", "party line" in lines() and "hi from the test" not in lines(), lines())
run("C.History_Select(3)")
check("filter by tab: Trade shows the channel line", "boost spam" in lines() and "party line" not in lines(), lines())
run("C.History_Select('ALL')")
check("filter All shows everything", "hi from the test" in lines() and "party line" in lines() and "boost spam" in lines())
# Chat 0.6.15: each open goes back to the active tab; whisper tabs as the game's New Whispers setting, or one Whispers tab
def reopen():
    C.History_Toggle(); C.History_Toggle()
    return str(run("local f=_G.XayaUIChatHistory local out={} for _,b in ipairs(f.kb) do if b:IsShown() then out[#out+1]=b.t._text end end return table.concat(out,',')"))
run("C.History_Select(2)")
reopen()
check("[Chat 0.6.15] closed on tab 2 and opened again: back on the active tab (General)", "hi from the test" in lines() and "party line" not in lines(), lines())
run("_G.__wm = 'popout'; local old = (_G.C_CVar and _G.C_CVar.GetCVar) or _G.GetCVar; _G.__oldGet = old; local f = function(k) if k == 'whisperMode' then return _G.__wm end return old and old(k) end; if _G.C_CVar then _G.C_CVar.GetCVar = f end; _G.GetCVar = f")
run("_G.GetNormalizedRealmName = function() return 'Realm' end")   # your realm: Realm
W.fireEvent("CHAT_MSG_WHISPER", "psst", "Ann-Realm")
W.fireEvent("CHAT_MSG_WHISPER_INFORM", "reply to ann", "Ann-Realm")
W.fireEvent("CHAT_MSG_WHISPER", "yo", "Bob-Other")
W.fireEvent("CHAT_MSG_WHISPER", "same name elsewhere", "Ann-Other")
W.fireEvent("CHAT_MSG_WHISPER", "no realm given", "Ann")
lab = reopen()
check("[Chat 0.6.16] game set to New Tab: one tab per conversation after the chat tabs, before Console and All; another realm's player is shown with the realm", lab == "General,Combat Log,Trade,Ann,Bob-Other,Ann-Other,Console,All", lab)
run("C.History_Select('W:ann-realm')")
check("[Chat 0.6.16] ...Ann (your realm)'s tab: her lines with and without the realm, and what you sent her; not Ann-Other's", "psst" in lines() and "reply to ann" in lines() and "no realm given" in lines() and "same name elsewhere" not in lines() and "yo" not in lines() and "party line" not in lines(), lines())
run("C.History_Select('W:ann-other')")
check("[Chat 0.6.16] ...Ann-Other has a tab of her own (Xaya: a realm is only left out when it is yours)", "same name elsewhere" in lines() and "psst" not in lines(), lines())
run("_G.__wm = 'popout_and_inline'")
check("[Chat 0.6.15] game set to Both: one tab per conversation too", reopen() == "General,Combat Log,Trade,Ann,Bob-Other,Ann-Other,Console,All")
run("_G.__wm = 'inline'")
lab = reopen()
check("[Chat 0.6.15] game set to In-line: no whisper tabs", lab == "General,Combat Log,Trade,Console,All", lab)
run("ns.chat2.histWhispers = 'one'")
lab = reopen()
check("[Chat 0.6.15] All whispers in one tab: a Whispers tab, whatever the game's setting", lab == "General,Combat Log,Trade,Whispers,Console,All", lab)
run("C.History_Select('WHISPERS')")
check("[Chat 0.6.15] ...the Whispers tab holds every whisper, sent and received, and nothing else", "psst" in lines() and "reply to ann" in lines() and "yo" in lines() and "party line" not in lines(), lines())
ak = run("local o = C.ScrollTarget; C.ScrollTarget = function() return { isTemporary = true, chatType = 'WHISPER', chatTarget = 'Ann' } end; local one = C.History_ActiveKey(); ns.chat2.histWhispers = 'game'; _G.__wm = 'popout'; local each = C.History_ActiveKey(); _G.__wm = 'inline'; local none = C.History_ActiveKey(); C.ScrollTarget = o; return tostring(one) .. ',' .. tostring(each) .. ',' .. tostring(none)")
check("[Chat 0.6.16] on one of the game's whisper windows (target 'Ann', your realm) the history opens on its conversation (each), the Whispers tab (one), or the first chat tab (none)", str(ak) == "WHISPERS,W:ann-realm,nil", ak)
check("[Chat 0.6.15] the default is to follow the game's setting", run("return ns.CHAT_DEFAULTS and ns.CHAT_DEFAULTS.histWhispers or (C.DEFAULTS and C.DEFAULTS.histWhispers)") == "game", run("return ns.CHAT_DEFAULTS and ns.CHAT_DEFAULTS.histWhispers"))
# (Chat 0.6.26; REQUEST-LOG UI-13 / UI-30 / UI-31: in-game and Battle.net lists, Individual / Consolidated / Both, a combine box;
# names "In-Game Whispers", "BNet Whispers", combined "Whispers"; default follows the game). Negative control: fails on Chat 0.6.25.
run("ns.chat2.histWhispers = 'game'; _G.__wm = 'inline'; ns.chat2.histWhispersW = 'one'; ns.chat2.histWhispersB = 'one'; ns.chat2.histWhispersCombine = false")
lab = reopen()
check("[Chat 0.6.26] both lists Consolidated, not combined: an In-Game Whispers tab and a BNet Whispers tab", lab == "General,Combat Log,Trade,In-Game Whispers,BNet Whispers,Console,All", lab)
run("C.History_Select('WHISPERS_W')")
check("[Chat 0.6.26] ...In-Game Whispers holds the character whispers", "psst" in lines() and "yo" in lines() and "party line" not in lines(), lines())
run("ns.chat2.histWhispersCombine = true")
lab = reopen()
check("[Chat 0.6.26] combined: one Whispers tab", lab == "General,Combat Log,Trade,Whispers,Console,All", lab)
run("ns.chat2.histWhispersW = 'both'; ns.chat2.histWhispersCombine = false; ns.chat2.histWhispersB = nil")
lab = reopen()
check("[Chat 0.6.26] in-game Both (Battle.net as the game, In-line): a tab per conversation and In-Game Whispers", lab == "General,Combat Log,Trade,Ann,Bob-Other,Ann-Other,In-Game Whispers,Console,All", lab)
dis = run("local t = ns.BuildChatTab(function() end); local o; local function f(g, d) for k, v in pairs(g.args or {}) do if k == 'whispersCombine' then o = v end; if type(v) == 'table' and v.type == 'group' and d < 5 then f(v, d + 1) end end end; f(t, 0); if not o then return 'missing' end; ns.chat2.histWhispersW = 'each'; local a = o.disabled(); ns.chat2.histWhispersW = 'one'; local b = o.disabled(); return tostring(a) .. ',' .. tostring(b)")
check("[Chat 0.6.26] the combine box is greyed unless a list has Consolidated or Both", str(dis) == "true,false", dis)
run("ns.chat2.histWhispersW = nil; ns.chat2.histWhispersB = nil; ns.chat2.histWhispersCombine = nil; _G.__wm = 'popout'")
lab = reopen()
check("[Chat 0.6.26] nothing chosen: follows the game (New Tab: a tab per conversation, no consolidated tab) (guard)", lab == "General,Combat Log,Trade,Ann,Bob-Other,Ann-Other,Console,All", lab)
run("_G.GetNormalizedRealmName = nil; if _G.C_CVar then _G.C_CVar.GetCVar = _G.__oldGet end; _G.GetCVar = _G.__oldGet; ns.chat2.histWhispers = 'game'; C.History_Select('ALL')")
# the window is a snapshot: new messages must not rewrite the text (that is what killed text selection)
run("_G.XayaUIChatHistory.edit._setCount = 0; local e=_G.XayaUIChatHistory.edit; local orig=e.SetText; e.SetText=function(self,t) self._setCount=(self._setCount or 0)+1; orig(self,t) end")
run("ns.chat2.histLive=false; C.History_Update()")
setn = int(run("return _G.XayaUIChatHistory.edit._setCount"))
for i in range(5):
    W.now += 1
    W.fireEvent("CHAT_MSG_CHANNEL", "more trade spam %d" % i, "Spam-Realm", "", "2. Trade - City", "", "", 0, 2, "Trade")
check("new messages do not rewrite the text while Live is off", int(run("return _G.XayaUIChatHistory.edit._setCount")) == setn, (setn, run("return _G.XayaUIChatHistory.edit._setCount")))
check("status says there are newer messages", "5 newer messages" in str(run("return _G.XayaUIChatHistory.status._text")), run("return _G.XayaUIChatHistory.status._text"))
W.click(hf.refresh)
check("Refresh brings them in", "more trade spam 4" in str(hf.edit._text), str(hf.edit._text)[-80:])
check("status up to date after Refresh", "Up to date" in str(hf.status._text))
W.click(hf.live)
check("Live on updates at once", run("return ns.chat2.histLive") is True)
W.now += 1
W.fireEvent("CHAT_MSG_SAY", "live line", "Hal-Realm")
check("Live on: new message appears", "live line" in str(hf.edit._text))
run("_G.XayaUIChatHistory.edit.HasFocus = function() return true end")
W.now += 1
W.fireEvent("CHAT_MSG_SAY", "typed line", "Hal-Realm")
check("Live on but text box focused (selecting): no rewrite", "typed line" not in str(hf.edit._text))
run("_G.XayaUIChatHistory.edit.HasFocus = nil; ns.chat2.histLive = false")
# resizing
check("history window is resizable with a grip", hf._resizable is True or run("return _G.XayaUIChatHistory.grip ~= nil"))
hf.SetSize(hf, 700, 420)
hf._scripts["OnSizeChanged"](hf)
check("resize relayouts the scroll area", rect(hf.scroll)[2] > 600, rect(hf.scroll))
run("local g=_G.XayaUIChatHistory.grip; g._scripts.OnMouseDown(g); g._scripts.OnMouseUp(g)")
check("size is remembered", run("return ns.chat2.histW") == 700 and run("return ns.chat2.histH") == 420, (run("return ns.chat2.histW"), run("return ns.chat2.histH")))
# tab buttons wrap instead of running into the search box
run("_G.XayaUIChatHistory:SetWidth(200)")
hf._scripts["OnSizeChanged"](hf)
tops = run("local f=_G.XayaUIChatHistory local ys={} for _,b in ipairs(f.kb) do if b:IsShown() then ys[#ys+1]=b._pts[1][5] end end return table.concat(ys,',')")
check("tab buttons wrap to a second row in a narrow window", len(set(str(tops).split(","))) >= 2, tops)
sr, br2 = rect(hf.search), rect(hf.kb[4])
check("search box sits below the last tab button row", sr[1] + sr[3] <= br2[1] + 0.5, (sr, br2))
# bottom of the window: the scroll area, the button row (Refresh, Live, status) and the note must be three separate bands, all inside
# the window and clear of the resize grip (the status line and the note used to be drawn over each other and behind the buttons)
for (w_, h_) in ((540, 380), (440, 300), (900, 600)):
    hf.SetSize(hf, w_, h_); hf._scripts["OnSizeChanged"](hf)
    run("_G.XayaUIChatHistory.status:SetText('1000 newer messages. Click Refresh.')")
    fr, sc, rf, lv, st, nt, gr = rect(hf), rect(hf.scroll), rect(hf.refresh), rect(hf.live), rect(hf.status), rect(hf.note), rect(hf.grip)
    tag = "%dx%d" % (w_, h_)
    check("footer %s: scroll area stays above the button row" % tag, sc[1] >= rf[1] + rf[3] - 0.5, (sc, rf))
    check("footer %s: button row stays above the note" % tag, rf[1] >= nt[1] + nt[3] - 0.5, (rf, nt))
    check("footer %s: note is inside the window and left of the grip" % tag, inside(hf.note, hf) and nt[0] + nt[2] <= gr[0] + 0.5, (nt, gr))
    check("footer %s: status starts right of Live and ends inside the window" % tag, st[0] >= lv[0] + lv[2] - 0.5 and inside(hf.status, hf), (st, lv))
    check("footer %s: status sits on the Live button's row (same vertical middle)" % tag, abs((st[1] + st[3] / 2) - (lv[1] + lv[3] / 2)) <= 0.5, (st, lv))
    check("footer %s: note holds two lines and stays below the button row" % tag, nt[3] >= 26 and nt[1] + nt[3] <= rf[1] + 0.5, (nt, rf))
    check("footer %s: status fits the width it has" % tag, hf.status.GetStringWidth(hf.status) <= st[2] + 0.5, (hf.status.GetStringWidth(hf.status), st))
hf.SetSize(hf, 540, 380); hf._scripts["OnSizeChanged"](hf)
C.History_Toggle()
check("history frame hides", hf.IsShown(hf) is False)

# ---- sounds ---------------------------------------------------------------------------------------------------------------
run("ns.chat2.soundsOn=true; ns.chat2.soundsInCombat=true; ns.chat2.sounds[1]={enabled=true,source='kit',value='3081'}; ns.chat2.sounds[2]={enabled=true,source='file',value='Interface\\\\x.ogg'}")
run("for k in pairs(W.played) do W.played[k]=nil end")
W.now += 1
W.fireEvent("CHAT_MSG_SAY", "hello", "Ian-R")
played = [str(v) for v in W.played.values()]
check("tab 1 (shows SAY) plays its sound; tab 2 does not", played == ["kit|3081"], played)
W.now += 1
for k in list(W.played.keys()): W.played[k] = None
W.fireEvent("CHAT_MSG_PARTY", "hello", "Jo-R")
played = [str(v) for v in W.played.values() if v is not None]
check("party message plays tab 2's sound only", played == ["file|Interface\\x.ogg"], played)
W.now += 1
for k in list(W.played.keys()): W.played[k] = None
W.fireEvent("CHAT_MSG_SAY", "mine", "Xaya")
check("own message plays nothing", len([v for v in W.played.values() if v is not None]) == 0)
W.now += 1
W.fireEvent("CHAT_MSG_WHISPER_INFORM", "outgoing", "Kai-R")
check("outgoing whisper plays nothing", len([v for v in W.played.values() if v is not None]) == 0)

# ---- whisper sound overrides (Chat 0.6.10; Xaya 2026-11-04) -----------------------------------------------------------------
def fired(ev, *args):
    W.now += 1
    for k in list(W.played.keys()): W.played[k] = None
    W.fireEvent(ev, *args)
    return sorted(str(v) for v in W.played.values() if v is not None)
def bn(bnID):   # a Battle.net whisper: arg13 is the sender's bnSenderID
    return fired("CHAT_MSG_BN_WHISPER", "hi", "|Kq1|k", "", "", "", "", 0, 0, "", 0, 1, "", bnID)
TABS = sorted(["kit|3081", "file|Interface\\x.ogg"])
BNTABS = []   # the stand-in tabs do not show Battle.net whispers: with no override, a Battle.net whisper plays nothing here
run("""C_ChatInfo = C_ChatInfo or {}; LOCKED = false; C_ChatInfo.InChatMessagingLockdown = function() return LOCKED end
C_BattleNet = C_BattleNet or {}
FRIENDS = { [7] = { battleTag = "AllTheFox#1872", isFavorite = false }, [8] = { battleTag = "Other#99", isFavorite = true } }
C_BattleNet.GetAccountInfoByID = function(id) return FRIENDS[id] end""")
check("no overrides: a whisper plays the tab sounds", fired("CHAT_MSG_WHISPER", "hi", "Kai-R") == TABS, fired("CHAT_MSG_WHISPER", "hi", "Kai-R"))
run("ns.chat2.whisperSounds.list[1] = { who = 'kai', enabled = true, source = 'kit', value = '999', channel = 'Master' }")
check("an override for 'kai': a whisper from Kai-R plays only its sound", fired("CHAT_MSG_WHISPER", "hi", "Kai-R") == ["kit|999"], fired("CHAT_MSG_WHISPER", "hi", "Kai-R"))
run("ns.chat2.whisperSounds.list[1].who = ' KAI-R '")
check("the full name works too, in any case and with spaces around it", fired("CHAT_MSG_WHISPER", "hi", "Kai-R") == ["kit|999"])
check("someone not on the list: the tab sounds", fired("CHAT_MSG_WHISPER", "hi", "Bob-R") == TABS)
run("ns.chat2.whisperSounds.list[2] = { who = 'allthefox', enabled = true, source = 'kit', value = '777', channel = 'Master' }")
check("Battle.net: a listed BattleTag (the part before #) plays its sound", bn(7) == ["kit|777"], bn(7))
run("ns.chat2.whisperSounds.list[2].who = 'AllTheFox#1872'")
check("Battle.net: the full BattleTag works too", bn(7) == ["kit|777"])
check("Battle.net: a favorite with no favorites sound set: the tab sounds (none here)", bn(8) == BNTABS, bn(8))
run("ns.chat2.whisperSounds.fav = { enabled = true, source = 'kit', value = '555', channel = 'Master' }")
check("Battle.net: a favorite plays the favorites sound", bn(8) == ["kit|555"], bn(8))
check("Battle.net: a listed sender wins over the favorites sound", (run("FRIENDS[7].isFavorite = true") or True) and bn(7) == ["kit|777"])
run("LOCKED = true")
check("chat lockdown: no override is looked up, the tab sounds play", fired("CHAT_MSG_WHISPER", "hi", "Kai-R") == TABS and bn(8) == BNTABS)
run("LOCKED = nil")
check("the game cannot say whether chat is locked down: the tab sounds", fired("CHAT_MSG_WHISPER", "hi", "Kai-R") == TABS)
run("LOCKED = false")
check("a secret sender name: the tab sounds", fired("CHAT_MSG_WHISPER", "hi", "<<secret>>") == TABS)
check("a secret Battle.net sender ID: the tab sounds (none here)", bn("<<secret>>") == BNTABS)
run("ns.chat2.whisperSoundsOn = false")
check("overrides switched off: the tab sounds", fired("CHAT_MSG_WHISPER", "hi", "Kai-R") == TABS)
run("ns.chat2.whisperSoundsOn = true; ns.chat2.soundsOn = false")
check("tab sounds off, an override still plays", fired("CHAT_MSG_WHISPER", "hi", "Kai-R") == ["kit|999"])
check("tab sounds off, an unlisted whisper plays nothing", fired("CHAT_MSG_WHISPER", "hi", "Bob-R") == [])
run("ns.chat2.soundsOn = true")
check("a SAY from a listed name still plays the tab sound (overrides are for whispers)", fired("CHAT_MSG_SAY", "hi", "Kai-R") == ["kit|3081"])
wopt = run("""local t = ns.BuildChatTab(function() end); local snd
for _, part in pairs(t.args) do if type(part) == 'table' and part.args and part.args.wAdd then snd = part end end
if not snd then for _, part in pairs(t.args) do for _, p2 in pairs(part.args or {}) do if type(p2) == 'table' and p2.args and p2.args.wAdd then snd = p2 end end end end
if not snd then return 'no sounds group' end
local n0 = #ns.chat2.whisperSounds.list
snd.args.wAdd.func()
local n1 = #ns.chat2.whisperSounds.list
local row = snd.args['w' .. n1]
row.args.who.set(nil, 'Zed-R')
row.args.snd.set(nil, 'kit|4242')
local okRow = ns.chat2.whisperSounds.list[n1].who == 'Zed-R' and ns.chat2.whisperSounds.list[n1].value == '4242' and row.hidden() == false
row.args.remove.func()
return (n1 == n0 + 1 and okRow and #ns.chat2.whisperSounds.list == n0 and snd.args['w' .. n1].hidden() == true) and 'ok' or ('bad ' .. n0 .. ' ' .. n1 .. ' ' .. tostring(okRow))""")
check("options: + Add a sender adds a row, its name and sound are saved, Remove takes it away", wopt == "ok", wopt)
run("ns.chat2.whisperSounds.list = {}; ns.chat2.whisperSounds.fav = nil; C_BattleNet.GetAccountInfoByID = nil")

# ---- options --------------------------------------------------------------------------------------------------------------
opt = run("return ns.BuildChatTab(function() end)")
check("options table builds", opt is not None)
tabs = run("local out={} for k,v in pairs(ns.BuildChatTab(function() end).args) do out[#out+1]=k end table.sort(out) return table.concat(out,',')")
check("all tabs present", all(t in str(tabs) for t in ["layout","look","bar","behavior","filters","history","sounds","privacy"]), tabs)
bad = run("""
local bad = {}
local function walk(t, path)
  for k, v in pairs(t.args or {}) do
    local p = path .. '/' .. k
    if v.type == 'group' then walk(v, p) end
    if type(v.name) ~= 'string' and type(v.name) ~= 'function' then bad[#bad+1] = p .. ':name' end
    if (v.type == 'toggle' or v.type == 'range' or v.type == 'select' or v.type == 'color' or v.type == 'input') and (type(v.get) ~= 'function' or type(v.set) ~= 'function') then bad[#bad+1] = p .. ':getset' end
    for _, fn in ipairs({'get','name','desc'}) do
      if type(v[fn]) == 'function' and v.type ~= 'group' then
        local ok, err = pcall(v[fn], {k})
        if not ok then bad[#bad+1] = p .. ':' .. fn .. ':' .. tostring(err):sub(1,80) end
      end
    end
  end
end
walk(ns.BuildChatTab(function() end), 'chat')
return table.concat(bad, '\\n')
""")
check("every option has name/get/set and its getters run", str(bad) == "", bad)

# ---- layout (Xaya, 2026-11-03): parts are left-pane nodes under Chat Panel; each part's sections are tabs ---------------------
shape = run("""
local o = ns.BuildChatTab(function() end)
local out = { o.childGroups }
out[#out+1] = (o.xuiSwitch and o.xuiSwitch.name == 'Enable Chat Panel' and o.args.enabled == nil) and 'row:enabled' or 'missing:row-switch'   -- (Chat 0.6.18, S1 #48)
for _, k in ipairs({ 'theme', 'intro' }) do out[#out+1] = (o.args[k] and o.args[k].type ~= 'group') and ('top:' .. k) or ('missing:' .. k) end
local headers = 0
local function walk(t) for _, v in pairs(t.args or {}) do if v.type == 'header' then headers = headers + 1 end if v.type == 'group' then walk(v) end end end
walk(o)
out[#out+1] = 'headers:' .. headers
for _, k in ipairs({ 'layout', 'look', 'bar', 'behavior', 'filters', 'history', 'privacy' }) do out[#out+1] = k .. ':' .. tostring(o.args[k] and o.args[k].childGroups) end
out[#out+1] = 'sounds:' .. tostring(o.args.sounds and o.args.sounds.childGroups)
out[#out+1] = 'layoutTop:' .. tostring(o.args.layout.args.enabled == nil and o.args.layout.args.theme == nil)
local p = o.args.privacy.args
out[#out+1] = 'privOrder:' .. tostring(p.tab_lookHdr.order < p.tab_btnHdr.order and p.tab_btnHdr.order < p.tab_areaHdr.order)
out[#out+1] = 'privTop:' .. tostring(p.on ~= nil and p.start ~= nil and p.btn == nil and p.tab_btnHdr.args.btn ~= nil)
out[#out+1] = 'blocks:' .. tostring(o.args.bar.args.tab_blocksHdr ~= nil and o.args.bar.args.tab_blocksHdr.args.slot1 ~= nil and o.args.bar.args.on ~= nil)
return table.concat(out, ' ')
""")
want = ["tree", "row:enabled", "top:theme", "top:intro", "headers:0", "layout:tab", "look:tab", "bar:tab", "behavior:tab", "filters:tab",
        "history:tab", "privacy:tab", "sounds:nil", "layoutTop:true", "privOrder:true", "privTop:true", "blocks:true"]
check("Chat Panel: parts under it, panel switches on its own page, sections as tabs (Privacy: Look, Button, Area)", str(shape).split() == want, shape)
opened = []
run("_G.__open = {}; ns.OpenSettingsPage = function(...) _G.__open = { ... } end")
run("C.OpenSettings('bar', 'tab_blocksHdr')")
# Chat 0.6.13: the Chat Panel's page is in the Blizzard UI Reskin tab (module "reskin"; Xaya 2026-11-05)
check("right-click path opens Blizzard UI Reskin > Chat Panel > Chat Bar > Blocks", str(run("return table.concat(_G.__open, '>')")) == "reskin>chatpanel>bar>tab_blocksHdr")

# ---- settings changes through the option setters actually refresh the layout ----------------------------------------------
run("""
local function find(t, key) for k, v in pairs(t.args or {}) do if k == key then return v end local r = v.args and find(v, key) if r then return r end end end
local o = ns.BuildChatTab(function() C.Schedule() end)
local w = find(o, 'w')
if w then w.set({}, 777) end
""")
W.flush()
check("width option applies to the layout", int(rect(pane)[2]) == 777, rect(pane))
run("ns.chat2.width=440; C.Layout()")

# ---- privacy cover --------------------------------------------------------------------------------------------------------
run("ns.ChatPrivacy_Set(true)")
cover = L.XayaUIChatPrivacy
btn = L.XayaUIChatPrivacyButton
check("cover shown when privacy is on", cover is not None and cover.IsShown(cover) is True)
check("cover inside the pane", inside(cover, pane), (rect(cover), rect(pane)))
cr_, ir_, tr_, br_ = rect(cover), rect(inputA), rect(textA), rect(bar)
check("cover covers the input line", cr_[0] <= ir_[0] and cr_[1] <= ir_[1] and cr_[0]+cr_[2] >= ir_[0]+ir_[2] and cr_[1]+cr_[3] >= ir_[1]+ir_[3], (cr_, ir_))
check("cover covers the text", cr_[1] <= tr_[1] and cr_[1]+cr_[3] >= tr_[1]+tr_[3])
check("cover leaves the tabs showing by default", cr_[1]+cr_[3] <= rect(tabsA)[1] + 0.01)
check("cover does not touch the bar", cr_[1] >= br_[1] + br_[3] - 0.01, (cr_, br_))
check("cover is above the edit box strata", cover.GetFrameStrata(cover) == "DIALOG" and cover.GetFrameLevel(cover) >= 100)
bb = rect(btn); cc = rect(cont)
check("privacy button beside the block", bb[0] >= cc[0] + cc[2] - 0.01 and btn.IsShown(btn), (bb, cc))
# audit D38 (Chat 0.6.32): the defaults say what players have always seen (no label, no border); a ticked label with no text reads "Chat hidden"
check("D38 privacy defaults: no border and no label (what players see)", run("return ns.CHAT_DEFAULTS.privBorder == false and ns.CHAT_DEFAULTS.privShowText == false") is True)
run("ns.chatDB.privShowText = true; ns.chatDB.privText = nil; ns.ChatPrivacy_Refresh()")
check("D38 a ticked label with no text typed reads Chat hidden", str(cover.label._text) == "Chat hidden", cover.label._text)
run("ns.chatDB.privShowText = nil; ns.ChatPrivacy_Refresh()")
# tab row under the cover (Xaya: "can't click on tabs if the privacy panel is active"; her setting had cover-tabs and reveal on)
run("ns.chatDB.privCoverTabs=true; ns.ChatPrivacy_Set(false); ns.ChatPrivacy_Set(true)")
W.update(0.3, 3)
cr2, tr2 = rect(cover), rect(tabsA)
check("cover-tabs: cover reaches over the tab row", cr2[1] + cr2[3] >= tr2[1] + tr2[3] - 0.01, (cr2, tr2))
tabx, taby = tr2[0] + 20, tr2[1] + tr2[3] / 2
check("cover-tabs: a click on the tab row misses the cover", run("return tostring(XayaUIChatPrivacy:HitTest(%s, %s))" % (tabx, taby)) == "false")
check("cover-tabs: a click on the text area still hits the cover", run("return tostring(XayaUIChatPrivacy:HitTest(%s, %s))" % (rect(textA)[0] + 20, rect(textA)[1] + rect(textA)[3] / 2)) == "true")
run("W.mouseX=%s; W.mouseY=%s" % (tabx, taby)) if False else None
check("cover-tabs: pointer over the tab row still counts as over the cover (reveal)", run("W.mouseX=%s; W.mouseY=%s; return tostring(XayaUIChatPrivacy:IsMouseOver())" % (tabx, taby)) == "true")
run("ns.chatDB.privCoverTabs=false; ns.ChatPrivacy_Set(false); ns.ChatPrivacy_Set(true)")
W.update(0.3, 3)
check("no cover-tabs: whole cover takes clicks again", run("local a,b,c,d = XayaUIChatPrivacy:GetHitRectInsets(); return tostring(c)") == "0")
run("C.SetCollapsed(true)")
W.update(0.3, 3)
check("collapsed: cover hides", cover.IsShown(cover) is False)
check("collapsed: privacy button hides", btn.IsShown(btn) is False)
run("C.SetCollapsed(false)")
W.update(0.3, 3)
check("expanded: cover back", cover.IsShown(cover) is True)
run("ns.ChatPrivacy_Set(false)")
check("privacy off: cover hidden", cover.IsShown(cover) is False)

# ---- the game's border pieces ------------------------------------------------------------------------------------------------
for suf in ["TopLeftTexture", "BottomRightTexture", "LeftTexture", "TopTexture"]:
    check("Blizzard border piece hidden: " + suf, L["ChatFrame1" + suf].IsShown(L["ChatFrame1" + suf]) is False)
L.ChatFrame1TopTexture.Show(L.ChatFrame1TopTexture)
check("Blizzard's Show on a border piece is undone", L.ChatFrame1TopTexture.IsShown(L.ChatFrame1TopTexture) is False)
L.ChatFrame1TopTexture.SetShown(L.ChatFrame1TopTexture, True)
check("Blizzard's SetShown(true) on a border piece is undone", L.ChatFrame1TopTexture.IsShown(L.ChatFrame1TopTexture) is False)
sb = cf1.ScrollBar; sb.SetShown(sb, True)
check("Blizzard's SetShown(true) on the scroll bar is undone", sb.IsShown(sb) is False)
tb_ = cf1.ScrollToBottomButton
check("back-to-newest arrow sits inside the text area", inside(tb_, textA), (rect(tb_), rect(textA)))

# ---- glued to the container after the game moves things ----------------------------------------------------------------------
cf1.ClearAllPoints(cf1); cf1.SetPoint(cf1, "BOTTOMLEFT", L.UIParent, "BOTTOMLEFT", 700, 500)
W.flush()
check("Blizzard re-anchors the chat window: glued back at once", rect(cf1) == rect(textA), (rect(cf1), rect(textA)))
cf1.SetPoint(cf1, "BOTTOMRIGHT", L.UIParent, "BOTTOMRIGHT", -100, 100)    # only one of the two anchors replaced
W.flush()
check("only one anchor changed: still glued (the old check missed this)", rect(cf1) == rect(textA), (rect(cf1), rect(textA)))
eb2 = L.ChatFrame1EditBox; eb2.ClearAllPoints(eb2); eb2.SetPoint(eb2, "TOPLEFT", L.UIParent, "TOPLEFT", 5, -5)
W.update(0.4, 2)
check("edit box re-anchored by the game: glued back by the upkeep", rect(eb2) == rect(inputA), (rect(eb2), rect(inputA)))
run("ns.chat2.x = 600; ns.chat2.y = 300; C.Layout()")
check("moving the container moves the chat with it", rect(cf1) == rect(textA) and int(rect(cont)[0]) == 600, (rect(cf1), rect(textA), rect(cont)))
run("ns.chat2.x = 24; ns.chat2.y = 90; C.Layout()")

# ---- mover: opaque, with the chat glued ---------------------------------------------------------------------------------------
run("C.ToggleMover()")
mv = L.XayaUIChatMover
check("mover covers the container exactly", rect(mv) == rect(cont))
check("mover is nearly opaque (the chat underneath must not show)", mv._bgc is not None and mv._bgc[4] >= 0.9, mv._bgc and mv._bgc[4])
run("C.ToggleMover()")

# ---- Locate ("show me where it is") -------------------------------------------------------------------------------------------
run("C.Locate(nil, 5)")
lab = run("local out={} for k,o in pairs(W.objects()) do if o._kind=='Frame' and o.label and o.label._text and o:IsShown() then out[#out+1]=o.label._text end end table.sort(out) return table.concat(out,'|')")
check("Locate outlines every piece, labeling hidden ones", "Tab row" in str(lab) and "Chat Data Panel" in str(lab) and "Blizzard button strip (hidden)" in str(lab) and "Social button (hidden)" in str(lab), lab)
W.now += 6; W.update(0.1, 2)
lab2 = run("local out={} for k,o in pairs(W.objects()) do if o._kind=='Frame' and o.label and o.label._text and o:IsShown() then out[#out+1]=o.label._text end end return #out")
check("outlines disappear after the time is up", int(lab2) == 0, lab2)
run("""local function find(t, key) for k, v in pairs(t.args or {}) do if k == key then return v end local r = v.args and find(v, key) if r then return r end end end
local o = ns.BuildChatTab(function() end)
find(o, 'scroll').set({}, 'SHOW')""")
check("changing a piece's setting flashes its outline", "Scroll bar" in str(run("local out={} for k,o in pairs(W.objects()) do if o._kind=='Frame' and o.label and o.label._text and o:IsShown() then out[#out+1]=o.label._text end end return table.concat(out,'|')")))
run("ns.chat2.scrollBar = 'HIDE'; C.Refresh(); C.LocateClear()")

# ---- bar blocks relayout when the bar's size settles ---------------------------------------------------------------------------
run("ns.chat2.barAlign3 = 'RIGHT'; C.Refresh()")
slot3 = run("local b=C.Bar() local k={} for _,o in ipairs(b._kids) do if o._kind=='Button' then k[#k+1]=o end end return k[3]")
def lastkid(o): return run('return ...', o) if False else run('local o=...; return o._kids[#o._kids]', o)
fs3 = lastkid(slot3)
check("block 3 'Right': text anchored to the right of its block", fs3._pts[1][1] == "RIGHT", fs3._pts[1][1])
run("ns.chat2.barAlign3 = 'LEFT'; C.Refresh()")
check("block 3 'Left': text anchored to the left of its block", lastkid(slot3)._pts[1][1] == "LEFT")
run("ns.chat2.width = 640; C.Layout()")
W.flush()
check("blocks follow the bar when it grows (size hook)", abs(rect(slot3)[0] + rect(slot3)[2] - (rect(bar)[0] + rect(bar)[2])) < 1.5, (rect(slot3), rect(bar)))
run("ns.chat2.width = 440; ns.chat2.barAlign3 = 'CENTER'; C.Layout()")

# ---- the command help keeps its pipe characters ---------------------------------------------------------------------------------
import re
for k in list(W.printed.keys()): W.printed[k] = None
run("C.Command('status')")
helptxt = " ".join(str(v) for v in W.printed.values() if v)
check("help text escapes pipes (no stray single |)", re.search(r"(?<!\|)\|(?!\|)", helptxt) is None and "on||off" in helptxt, helptxt[:160])

# ---- turning the Chat Panel off gives Blizzard's chat back --------------------------------------------------------------------------
orig = {"cf1": (30.0, 40.0, 430.0, 120.0)}
run("C.Command('off')")
check("off: chat window is back at its own place", rect(cf1) == orig["cf1"], rect(cf1))
check("off: edit box back under its window", rect(L.ChatFrame1EditBox)[0] == 25 and rect(L.ChatFrame1EditBox)[1] == 40 - 2 - 32, rect(L.ChatFrame1EditBox))
check("off: dock manager back above its window", int(rect(L.GeneralDockManager)[1]) == 164, rect(L.GeneralDockManager))
check("off: button strip shown again", L.ChatFrame1ButtonFrame.IsShown(L.ChatFrame1ButtonFrame) is True)
check("off: social button shown again", L.QuickJoinToastButton.IsShown(L.QuickJoinToastButton) is True)
check("off: scroll bar and border pieces shown again", sb.IsShown(sb) is True and L.ChatFrame1TopTexture.IsShown(L.ChatFrame1TopTexture) is True)
check("off: chat alpha 1 and mouse on", cf1.GetAlpha(cf1) > 0.99 and L.ChatFrame1Tab.GetAlpha(L.ChatFrame1Tab) > 0.99)
check("off: our container hidden", cont.IsShown(cont) is False)
check("off: our privacy cover and button hidden", (L.XayaUIChatPrivacyButton is None) or L.XayaUIChatPrivacyButton.IsShown(L.XayaUIChatPrivacyButton) is False)
check("off: game's chat font is back", cf1._font[1] == "Fonts\\ARIALN.TTF" and cf1._font[2] == 14, (cf1._font[1], cf1._font[2]))
check("off: tab height back", L.ChatFrame1Tab.GetHeight(L.ChatFrame1Tab) == 32, L.ChatFrame1Tab.GetHeight(L.ChatFrame1Tab))
cf1.ClearAllPoints(cf1); cf1.SetPoint(cf1, "BOTTOMLEFT", L.UIParent, "BOTTOMLEFT", 300, 300)
W.flush(); W.update(0.5, 3)
check("off: the game can move its chat and we do not fight it", rect(cf1)[0] == 300, rect(cf1))
run("C.Command('on')")
W.flush(); W.update(0.4, 2)
check("on again: glued to the container", rect(cf1) == rect(textA) and rect(L.ChatFrame1EditBox) == rect(inputA), (rect(cf1), rect(textA)))
check("on again: strip hidden once more", L.ChatFrame1ButtonFrame.IsShown(L.ChatFrame1ButtonFrame) is False)

# ---- commands -------------------------------------------------------------------------------------------------------------
for k in list(W.printed.keys()): W.printed[k] = None
run("C.Command('status')")
check("/xui chat status prints", any(v for v in W.printed.values() if v))
# /xui chat indent: read-only report of the space at the left of the text; shows |-codes as typed and never reads protected text
# (Chat 0.6.20 / Dev Assist 0.7.5, REQUEST-LOG #81: the report is XayaUI Dev Assist's; loaded here as the game would, after XayaUI Chat)
W.loadDevAssist(W)
for k in list(W.printed.keys()): W.printed[k] = None
run("local cf = C.Main(); cf.visibleLines = { { IsShown = function() return true end, GetText = function() return '|cff808080' .. '05:11 |rhello there' end, GetLeft = function() return 41 end } } ; C.Command('indent')")
out = " ".join(str(v) for v in W.printed.values() if v)
check("/xui chat indent prints the measures", "text area left" in out and "box left" in out, out[:200])
check("/xui chat indent shows the |-codes as typed", "||cff808080" in out and "05:11" in out, out[:300])
for k in list(W.printed.keys()): W.printed[k] = None
run("local cf = C.Main(); cf.visibleLines = { { IsShown = function() return true end, GetText = function() return 'secret text' end, GetLeft = function() return 41 end } }; local old = C.IsSecret; C.IsSecret = function(v) return v == 'secret text' end; C.Command('indent'); C.IsSecret = old")
out = " ".join(str(v) for v in W.printed.values() if v)
check("/xui chat indent never prints protected text", "secret text" not in out and "empty or protected" in out, out[:300])
for k in list(W.printed.keys()): W.printed[k] = None
run("local cf = C.Main(); cf.visibleLines = { { IsShown = function() return true end, GetText = function() error('boom') end } }; C.Command('indent')")
out = " ".join(str(v) for v in W.printed.values() if v)
check("/xui chat indent: a line that cannot be read ends the report with a message, not an error", "could not finish" in out, out[:300])
run("C.Main().visibleLines = nil")
check("/xui chat indent causes no module error", len(list(C.errors.keys())) == 0, dict(C.errors))
# audit D31 (Chat 0.6.32): turning the Chat Panel off gives the game's own fade of old lines back (stand-in: on, 120 s)
run("ns.chat2.textFade = false; C.Refresh()")
check("D31 with the panel on and its text fade off, the game's fade is off", run("return C.Main()._fading") is False, run("return C.Main()._fading"))
run("C.Command('off')")
check("/xui chat off sets enabled=false", run("return ns.chat2.enabled") is False)
check("D31 /xui chat off gives the game's fade back (on, 120 s)", run("return C.Main()._fading") is True and run("return C.Main()._timeVisible") in (None, 120), (run("return C.Main()._fading"), run("return C.Main()._timeVisible")))
run("C.Command('on')")
check("/xui chat on sets enabled=true", run("return ns.chat2.enabled") is True)
run("C.Command('move')")
check("mover toggles on", C.unlocked is True)
run("C.Command('move')")
check("mover toggles off", C.unlocked is False)
run("ns.chat2.x=999; C.Command('reset')")
check("reset restores the position", run("return ns.chat2.x") == run("return C.DEFAULTS.x"))

# ---- other addon guard ----------------------------------------------------------------------------------------------------
run("_G.ElvUI = {} ")
check("(info) BlockedReason with ElvUI global only", True)

# ---- wrapping: a message frame that laid its lines out at an old width is noticed and laid out again ----------------------------
r = run("""
local cf = C.Main()
local calls = { dirty = 0, refresh = 0 }
cf.MarkLayoutDirty = function() calls.dirty = calls.dirty + 1 end
cf.RefreshIfNecessary = function() calls.refresh = calls.refresh + 1 end
local w = cf:GetWidth()
local function line(width, str) return { GetWidth = function() return width end, GetStringWidth = function() return 9999 end, GetWrappedWidth = function() return str end } end
cf.visibleLines = { line(w, 100), line(w, 120) }
local out = {}
out.okWhenSame = (C.WrapOff() == false)
cf.visibleLines = { line(w + 30, 100), line(w + 30, 150) }
out.offWhenStale = (C.WrapOff() == true)
local st = C.WrapStatus()
out.wrapped = st.wrapped; out.over = st.over; out.lineW = st.line; out.cfW = st.cf
cf.visibleLines = { line(w, w + 40), line(w, 100) }
out.overflow = C.WrapStatus().over
cf.visibleLines = { line(w + 30, 100), line(w + 30, 150) }
out.did = C.Rewrap(true)
out.dirty, out.refresh = calls.dirty, calls.refresh
local again = C.Rewrap()   -- throttled: not within the same second unless forced
out.throttled = (again == false)
cf.visibleLines = nil
out.noLines = (C.WrapOff() == false)
return out
""")
check("wrap: consistent widths are left alone", bool(r.okWhenSame))
check("wrap: a stale line width is detected", bool(r.offWhenStale))
check("wrap: status reports the widest WRAPPED line, not the one-line text width", r.wrapped == 150 and r.lineW == r.cfW + 30, (r.wrapped, r.lineW, r.cfW))
check("wrap: no line wider than its box is counted as 0", r.over == 0, r.over)
check("wrap: a wrapped line wider than its box is counted", r.overflow == 1, r.overflow)
check("wrap: Rewrap only marks the layout dirty (secure); it never runs the game's layout code itself", r.did and r.dirty == 1 and r.refresh == 0, (r.did, r.dirty, r.refresh))
check("wrap: Rewrap is throttled", bool(r.throttled))
check("wrap: no lines table is not an error", bool(r.noLines))

# ---- indent wrapped lines (0.6.5): set again after the font changes; off restores the game's value -----------------------------
r = run("""
local cf = C.Main(); local out = {}
cf._indent = false; cf._indentCalls = 0; cf._xuiIndent = nil
C.Refresh(); W.flush()
out.onAfterRefresh = cf._indent; out.calls1 = cf._indentCalls
C.Refresh(); W.flush()
out.calls2 = cf._indentCalls
ns.chat2.wrapIndent = false; C.Refresh(); W.flush(); out.offWhenOff = (cf._indent == false)
ns.chat2.wrapIndent = true; C.Refresh(); W.flush()
ns.chat2.enabled = false; C.Refresh(); W.flush(); out.restored = cf._indent
ns.chat2.enabled = true; C.Refresh(); W.flush()
out.cf2 = W.cf2._indent
return out
""")
check("indent: wrapped lines indented again after the Chat Panel sets the font", r.onAfterRefresh is True, r.onAfterRefresh)
check("indent: set only when it differs (each set lays the lines out again)", r.calls1 == 1 and r.calls2 == 1, (r.calls1, r.calls2))
check("indent: the setting turns it off", bool(r.offWhenOff))
check("indent: turning the Chat Panel off gives the game's own value back", r.restored is False, r.restored)
check("indent: docked ChatFrame2 gets it too", r.cf2 is True, r.cf2)
L.ChatFrame1.visibleLines = None
run("for k in pairs(W.printed) do W.printed[k] = nil end; C.Command('indent'); C.Command('wrap')")
out = "\n".join(str(v) for v in run("return W.printed").values())
check("/xui chat indent reports the indent setting and the window's value", "indent wrapped lines: setting on, the window's font on" in out, out[:600])
check("/xui chat wrap no longer prints the one-line text width as 'widest text'", "widest text" not in out and "widest wrapped line" in out, out[:600])

# ---- the Chat Panel scroll bar (0.6.5) ---------------------------------------------------------------------------------------
sb, upB, downB, trk, th = L.XayaUIChatScrollBar, L.XayaUIChatScrollUp, L.XayaUIChatScrollDown, L.XayaUIChatScrollTrack, L.XayaUIChatScrollThumb
check("scroll bar: built and shown by default", sb is not None and sb.IsShown(sb) is True)
check("scroll bar: inside the pane", inside(sb, pane), (rect(sb), rect(pane)))
tr, sr = rect(textA), rect(sb)
check("scroll bar: right of the text, not over it", sr[0] >= tr[0] + tr[2] - 0.01, (tr, sr))
check("scroll bar: as tall as the text area", abs(sr[3] - tr[3]) < 0.01 and abs(sr[1] - tr[1]) < 0.01, (tr, sr))
check("scroll bar: chat window still fills the text area", rect(cf1) == rect(textA))
check("scroll bar: Blizzard's own scroll bar hidden while ours is on", cf1.ScrollBar.IsShown(cf1.ScrollBar) is False)
check("scroll bar: arrows and track inside the bar", inside(upB, sb) and inside(downB, sb) and inside(trk, sb))
r = run("""
local cf = C.Main(); local out = {}
cf._off, cf._max, cf._vis, cf._calls = 0, 50, 10, {}
local up, down = _G.XayaUIChatScrollUp, _G.XayaUIChatScrollDown
up._scripts.OnMouseDown(up, "LeftButton"); out.afterClick = cf._off
up._scripts.OnMouseUp(up)
W.update(1.0, 1); out.noRepeatAfterRelease = cf._off
up._scripts.OnMouseDown(up, "LeftButton")
W.update(0.3, 1); out.beforeDelay = cf._off          -- still inside the pause before repeating
W.update(0.05, 1); W.update(1.0, 1); out.afterHold = cf._off
up._scripts.OnMouseUp(up)
down._scripts.OnMouseDown(down, "LeftButton"); down._scripts.OnMouseUp(down); out.afterDown = cf._off
local bar = _G.XayaUIChatScrollBar
bar._scripts.OnMouseWheel(bar, 1); out.afterWheel = cf._off
local secure = true
for _, c in ipairs(cf._calls) do if c ~= "ScrollByAmount" and c ~= "SetScrollOffset" and c ~= "PageUp" and c ~= "PageDown" then secure = false end end
out.secureOnly = secure
-- the thumb: at the bottom when at the newest line, at the top when at the oldest
cf._off = 0; C.ScrollBar_Update(); local th, tr = _G.XayaUIChatScrollThumb, _G.XayaUIChatScrollTrack
out.thumbBottomAtNewest = math.abs(th:GetBottom() - tr:GetBottom()) < 0.01
cf._off = cf._max; C.ScrollBar_Update()
out.thumbTopAtOldest = math.abs(th:GetTop() - tr:GetTop()) < 0.01
out.thumbSmaller = th:GetHeight() < tr:GetHeight()
cf._max = 0; cf._off = 0; C.ScrollBar_Update(); out.fullWhenNothing = math.abs(th:GetHeight() - tr:GetHeight()) < 0.01
cf._max = 50
return out
""")
check("scroll bar: one click on the up arrow moves exactly one line", r.afterClick == 1, r.afterClick)
check("scroll bar: nothing more after the arrow is let go", r.noRepeatAfterRelease == 1, r.noRepeatAfterRelease)
check("scroll bar: holding waits a moment before repeating", r.beforeDelay == 2, r.beforeDelay)
check("scroll bar: holding repeats at the set speed (6 lines a second by default)", 7 <= r.afterHold <= 9, r.afterHold)
check("scroll bar: the down arrow moves one line toward the newest", r.afterDown == r.afterHold - 1, (r.afterHold, r.afterDown))
check("scroll bar: the mouse wheel over the bar scrolls one line", r.afterWheel == r.afterDown + 1, r.afterWheel)
check("scroll bar: only the window's secure scroll methods are called", bool(r.secureOnly))
check("scroll bar: thumb at the bottom at the newest line", bool(r.thumbBottomAtNewest))
check("scroll bar: thumb at the top at the oldest line", bool(r.thumbTopAtOldest))
check("scroll bar: thumb shorter than the track when there is more to scroll", bool(r.thumbSmaller))
check("scroll bar: full-height thumb when there is nothing to scroll", bool(r.fullWhenNothing))
run("ns.chat2.scrollOwn = false; ns.chat2.scrollBar = 'SHOW'; C.Refresh(); W.flush()")
check("scroll bar: off hides it", sb.IsShown(sb) is False)
check("scroll bar: off + Blizzard's shown brings Blizzard's back", cf1.ScrollBar.IsShown(cf1.ScrollBar) is True)
check("scroll bar: off gives the space back (Blizzard's 14 px only)", abs((rect(pane)[0] + rect(pane)[2]) - (rect(textA)[0] + rect(textA)[2]) - (2 + 6 + 14)) < 0.01, (rect(pane), rect(textA)))
run("ns.chat2.scrollOwn = true; ns.chat2.scrollBar = 'HIDE'; C.Refresh(); W.flush()")
check("scroll bar: back on", sb.IsShown(sb) is True and inside(sb, pane))

# ---- history Console tab (0.6.5) -----------------------------------------------------------------------------------------------
r = run("""
local out = {}
local before = C.History_ConsoleCount()
print("|cff33ccffXayaUI|r: Chat Panel wrap: window width 426.0")
W.fireEvent("CHAT_MSG_SYSTEM", "You are now Away: AFK")
print("<<secret>>")
out.added = C.History_ConsoleCount() - before
out.stillPrinted = W.rawPrinted[#W.rawPrinted] == "<<secret>>"
C.History_Select("CONSOLE"); out.console = table.concat(C.History_Lines(), "\\n")
C.History_Select("ALL"); out.all = table.concat(C.History_Lines(), "\\n")
ns.chat2.histConsole = false
local n = C.History_ConsoleCount(); print("not kept"); out.offKeepsNothing = (C.History_ConsoleCount() == n)
ns.chat2.histConsole = true
return out
""")
check("console: print() lines, system messages and protected prints are kept", r.added == 3, r.added)
check("console: the game still prints the line (post-hook only)", bool(r.stillPrinted))
check("console: colors removed, text kept", "XayaUI: Chat Panel wrap: window width 426.0" in str(r.console) and "|c" not in str(r.console), r.console)
check("console: system messages tagged", "System You are now Away: AFK" in str(r.console), r.console)
check("console: protected text listed as protected, never printed", "[protected message]" in str(r.console) and "<<secret>>" not in str(r.console), r.console)
check("console: kept out of the All tab", "426.0" not in str(r.all) and "AFK" not in str(r.all), r.all)
check("console: the setting off keeps nothing", bool(r.offKeepsNothing))
# Chat 0.6.17 (Xaya 2026-11-06: fix the history window's "|" in this update): a printed "||" (the game's escape for one "|") lost the "|"
# and sometimes the letter after it in the history window ("[highlighttrail]", "statusidthprobe" in her screenshot). The window's edit
# box now gets every literal pipe doubled; C.History_Lines (what search reads) keeps one.
r = run("""
local out = {}
print("|cff33ccffXayaUI|r:   |cffffffff/xui cursor [highlight||trail]|r  cursor settings; /xui stats [on||off||options||status]")
C.History_Select("CONSOLE")
out.lines = table.concat(C.History_Lines(), "\\n")
C.History_Toggle()
local f = _G.XayaUIChatHistory
out.edit = f and f.edit and f.edit:GetText() or ""
f.search:SetText("on||off"); f.search:GetScript("OnTextChanged")(f.search)
out.found = table.concat(C.History_Lines(), "\\n")
f.search:SetText(""); f.search:GetScript("OnTextChanged")(f.search)
C.History_Toggle()
C.History_Select("ALL")
return out
""")
check("history '|': the lines (search, copy) read one '|': [highlight|trail], [on|off|options|status]",
      "[highlight|trail]" in str(r.lines) and "[on|off|options|status]" in str(r.lines), r.lines)
check("history '|': the edit box gets each '|' doubled, so none starts a code (shown as one '|')",
      "[highlight||trail]" in str(r.edit) and "[on||off||options||status]" in str(r.edit) and "[highlight|trail]" not in str(r.edit), r.edit)
check("history '|': a search typed with '|' (the box gives it back doubled) finds the line", "[on|off|options|status]" in str(r.found), r.found)
# Chat 0.6.19 (REQUEST-LOG O-81): up to 0.6.18 C.Plain took the codes out BEFORE collapsing "||", so the second "|" of a pair and a
# letter that starts a code (r, n, c, T, H, A, K) went missing: the /xui chat status line "on||off||reset" read "on|off|eset".
for raw, want in (("on||off||reset||move", "on|off|reset|move"), ("[on||none]", "[on|none]"), ("a||cffff0000b", "a|cffff0000b"),
                  ("|||r", "|"), ("x||Ty||tz", "x|Ty|tz"), ("[highlight||trail]", "[highlight|trail]"),
                  ("status||widthprobe", "status|widthprobe"), ("|cffff0000red|r ||n", "red |n")):
    got = run("return C.Plain(...)", raw)
    check("history '|' [0.6.19]: C.Plain(%r) == %r" % (raw, want), str(got) == want, got)
r = run("""
local out = {}
print("|cff33ccffXayaUI|r: " .. ("Chat Panel: ON. /xui chat on|off|reset|move|history|wrap|indent|whispers|settings"):gsub("|", "||"))
C.History_Select("CONSOLE")
out.lines = table.concat(C.History_Lines(), "\\n")
C.History_Toggle()
local f = _G.XayaUIChatHistory
out.edit = f and f.edit and f.edit:GetText() or ""
C.History_Toggle()
C.History_Select("ALL")
return out
""")
check("history '|' [0.6.19]: the /xui chat status line keeps every letter in the Console tab (on|off|reset|move|history)",
      "/xui chat on|off|reset|move|history|wrap|indent|whispers|settings" in str(r.lines), r.lines)
check("history '|' [0.6.19]: the edit box gets that line with each '|' doubled (on||off||reset)",
      "on||off||reset||move||history" in str(r.edit), r.edit)
run("C.History_Toggle()")
names = str(run("local t = {}; for _, b in ipairs(_G.XayaUIChatHistory.kb) do if b:IsShown() then t[#t + 1] = b.t:GetText() end end; return table.concat(t, ',')"))
check("console: the history window has a Console tab button", "Console" in names, names)
run("C.History_Toggle()")

# ---- chat probe: a secret 'shown' no longer stops the probe (0.6.4: Probe.lua:229) -------------------------------------------
probe = open(os.path.join(ROOT, "XayaUI_DevAssist", "ChatProbe.lua")).read()   # (moved from XayaUI_Chat/Probe.lua, Dev Assist 0.7.5)
check("probe: 'shown' is checked for secret before it is compared", "not secret(shown) and shown == true" in probe)

# ---- #346: the game's clamp-to-screen margin pushed the chat window off the text area at the screen edge ---------------------------
r = run("""local out = {}
local cf = C.Main()
ns.chat2.enabled = false; C.Refresh(); W.flush()
cf:SetClampedToScreen(true); cf:SetClampRectInsets(-32, 0, 0, 0); cf._xuiClamp = nil
ns.chat2.enabled = true; C.Refresh(); W.flush()
out.onClamped = cf:IsClampedToScreen()
cf:SetClampedToScreen(true)                    -- the game turns it back on
out.glued = C.Glued()
C.Anchor(); W.flush()
out.again = cf:IsClampedToScreen()
ns.chat2.enabled = false; C.Refresh(); W.flush()
out.offClamped = cf:IsClampedToScreen()
ns.chat2.enabled = true; C.Refresh(); W.flush()
return out""")
check("#346: the chat window is not clamped to the screen while the Chat Panel is on", r["onClamped"] is False)
check("#346: clamped again by the game = not glued (anchors again)", r["glued"] is False)
check("#346: anchoring again unclamps it", r["again"] is False)
check("#346: Chat Panel off gives the game its clamp back", r["offClamped"] is True)
for k in list(W.printed.keys()): W.printed[k] = None
run("local cf = C.Main(); cf:SetClampRectInsets(-32, 0, 0, 0); cf.visibleLines = { { IsShown = function() return true end, GetText = function() return 'hi' end, GetLeft = function() return 41 end } }; C.Command('indent')")
out = " ".join(str(v) for v in W.printed.values() if v)
check("#346: /xui chat indent prints the clamp state and margins", "clamped to the screen: no" in out and "clamp margins left -32.0" in out, out[:400])

check("no module errors at the end", len(list(C.errors.keys())) == 0, dict(C.errors))
print("\n%d failed" % fails if fails else "\nall passed")
sys.exit(1 if fails else 0)
