# Chat 0.6.12: the pieces Xaya saw in the wrong place (2026-11-04, screenshot with the Party tab selected):
#   1. "the selector gets hidden by the privacy icon": the tab row's window list ("7 Chat Windows") was drawn under the privacy button;
#   2. "scroll to the bottom button is hidden by scroll bar": with a tab other than ChatFrame1 selected, the game's scroll bar and its
#      back-to-newest arrow stayed right of the text, in the column of the Chat Panel's scroll bar;
#   3. "whispers are not shown as their own tabs": no cause in the Chat Panel's code; /xui chat whispers reports what the game did.
# Uses tests/chat_world.lua (stand-in frames with real anchor geometry). Checks logic and placement, not the real game.
# Run from the repo root: python3 tests/chat_pieces_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
lua = LuaRuntime(unpack_returned_tuples=True)
W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1
def run(code, *args):
    return lua.eval("function(W, ns, C, ...) " + code + " end")(W, W.ns, W.ns.Chat, *args)

# The game's pieces the stand-in world does not have yet, as FloatingChatFrame.xml / .lua build them (wow-ui-source live 12.1.5.70783):
# the dock's overflow arrow and its list (no strata of its own: it is drawn in the dock's LOW layer), the back-to-newest arrow at alpha 0,
# a docked window anchored on the primary one (FCFDock_AddChatFrame: chatFrame:SetAllPoints(dock.primary)), the whisper manager.
run("""
local dock = GeneralDockManager
dock._strata = "LOW"
local ob = W.new("Button", "GeneralDockManagerOverflowButton", dock); ob._w, ob._h = 16, 16; ob._strata = "LOW"
ob:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
local list = W.new("Frame", "GeneralDockManagerOverflowButtonList", ob); list._w, list._h = 160, 25 + 7 * 19; list._strata = "LOW"
list:SetPoint("LEFT", ob, "RIGHT", 0, 0)
dock.overflowButton = ob; ob.list = list
GENERAL_CHAT_DOCK = dock
dock.DOCKED_CHAT_FRAMES = { W.cf1, W.cf2 }
for _, cf in ipairs({ W.cf1, W.cf2, W.cf3 }) do cf.ScrollToBottomButton._alpha = 0 end
W.cf2:ClearAllPoints(); W.cf2:SetAllPoints(W.cf1)
FloatingChatFrameManager = W.new("Frame", "FloatingChatFrameManager", UIParent)
for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }) do FloatingChatFrameManager:RegisterEvent(ev) end
function FloatingChatFrameManager:IsEventRegistered(ev) return self._events[ev] and true or false end
W.cvars = { whisperMode = "popout" }
C_CVar = { GetCVar = function(k) return W.cvars[k] end }
""")
S = W.start()
L = lua.globals()
C = W.ns.Chat
check("no module errors at start", len(list(C.errors.keys())) == 0, dict(C.errors))

def rect(o):
    r = W.rect(o); return (r.l, r.b, r.w, r.h)
def inside(inner, outer, tol=0.01):
    a, b = rect(inner), rect(outer)
    return a[0] >= b[0]-tol and a[1] >= b[1]-tol and a[0]+a[2] <= b[0]+b[2]+tol and a[1]+a[3] <= b[1]+b[3]+tol
def overlap(a, b):
    ra, rb = rect(a), rect(b)
    return ra[0] < rb[0] + rb[2] - 0.01 and rb[0] < ra[0] + ra[2] - 0.01 and ra[1] < rb[1] + rb[3] - 0.01 and rb[1] < ra[1] + ra[3] - 0.01
STRATA = ["BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP"]
def rank(o): return STRATA.index(o.GetFrameStrata(o))
def above(a, b):   # a is drawn over b: a higher layer, or the same layer and a higher level
    return rank(a) > rank(b) or (rank(a) == rank(b) and a.GetFrameLevel(a) > b.GetFrameLevel(b))

textA, pane = C.TextArea(), C.Pane()
cf1, cf2 = W.cf1, W.cf2
ownBar = L.XayaUIChatScrollBar
privBtn = L.XayaUIChatPrivacyButton
histBtn = L.XayaUIChatHistoryButton
tabList = L.GeneralDockManagerOverflowButtonList

# ---- 1. the tab row's window list over the privacy button -------------------------------------------------------------------
check("world: the window list hangs over the privacy button, as in Xaya's screenshot", overlap(tabList, privBtn), (rect(tabList), rect(privBtn)))
check("world: and over the Chat Panel's scroll bar and history button", overlap(tabList, ownBar) and overlap(tabList, histBtn),
      (rect(tabList), rect(ownBar), rect(histBtn)))
check("the window list is drawn over the privacy button", above(tabList, privBtn), (tabList.GetFrameStrata(tabList), privBtn.GetFrameStrata(privBtn)))
check("the window list is drawn over the Chat Panel's scroll bar and history button", above(tabList, ownBar) and above(tabList, histBtn))
run("ns.ChatPrivacy_Set(true)")
cover = L.XayaUIChatPrivacy
check("the window list is drawn over the privacy cover too (it reaches into the pane)", cover is not None and above(tabList, cover),
      cover and cover.GetFrameStrata(cover))
run("ns.ChatPrivacy_Set(false)")
check("the window list uses the layer of the game's own drop-down menus (FULLSCREEN_DIALOG)", tabList.GetFrameStrata(tabList) == "FULLSCREEN_DIALOG")
run("ns.chat2.enabled = false; C.Refresh(); W.flush()")
check("Chat Panel off: the window list is back in its own layer", tabList.GetFrameStrata(tabList) == "LOW", tabList.GetFrameStrata(tabList))
run("W.combat = true; ns.chat2.enabled = true; C.Refresh(); W.flush()")
check("in combat: the window list's layer is not changed", tabList.GetFrameStrata(tabList) == "LOW", tabList.GetFrameStrata(tabList))
run("W.combat = false; W.update(0.4, 12)")   # the upkeep runs C.Parts every 3 seconds
check("after combat: the upkeep raises it", tabList.GetFrameStrata(tabList) == "FULLSCREEN_DIALOG", tabList.GetFrameStrata(tabList))

# ---- 2. every docked window's scroll bar and back-to-newest arrow (another tab selected) ---------------------------------------
run("SELECTED_DOCK_FRAME = W.cf2; SELECTED_CHAT_FRAME = W.cf2; W.cf2.ScrollBar:Show(); C.Refresh(); W.flush(); W.update(0.4, 1)")
check("selected tab: the pane shows ChatFrame2 (the scroll bar scrolls it)", run("return C.ScrollTarget() == W.cf2") is True)
sb2, tb2, rz2 = cf2.ScrollBar, cf2.ScrollToBottomButton, cf2.ResizeButton
check("ChatFrame2 (docked): the game's own scroll bar is hidden while the Chat Panel's is on", sb2.IsShown(sb2) is False)
sb2.SetShown(sb2, True)
check("ChatFrame2: the game's SetShown(true) on its scroll bar is undone", sb2.IsShown(sb2) is False)
check("ChatFrame2: the resize grip is hidden", rz2.IsShown(rz2) is False)
check("ChatFrame2: the back-to-newest arrow sits inside the text area", inside(tb2, textA), (rect(tb2), rect(textA)))
check("ChatFrame2: the back-to-newest arrow is clear of the Chat Panel's scroll bar", not overlap(tb2, ownBar), (rect(tb2), rect(ownBar)))
check("ChatFrame2: and inside the pane", inside(tb2, pane))
tb1 = cf1.ScrollToBottomButton
check("ChatFrame1's arrow keeps its place (inside the text area, clear of the scroll bar)", inside(tb1, textA) and not overlap(tb1, ownBar))

def seen(o): return bool(o.IsShown(o)) and o.GetAlpha(o) > 0.5
run("W.cf2._off = 0; W.update(0.4, 1)")
check("at the newest line: the arrow is not shown (it would only cover the last line)", not seen(tb2))
run("W.cf2._off = 5; W.update(0.4, 1)")
check("scrolled up: the arrow is seen (the game's own fade never shows it while its scroll bar is hidden)", seen(tb2),
      (tb2.IsShown(tb2), tb2.GetAlpha(tb2)))
check("scrolled up: still clear of the scroll bar and inside the text", inside(tb2, textA) and not overlap(tb2, ownBar))
run("W.cf1._off = 3; W.update(0.4, 1)")
check("ChatFrame1 scrolled up: its arrow is seen too", seen(tb1), (tb1.IsShown(tb1), tb1.GetAlpha(tb1)))
run("W.cf1._off = 0; W.update(0.4, 1)")
check("ChatFrame1 back at the newest line: its arrow goes", not seen(tb1))
run("W.cf2.GetScrollOffset = function() return '<<secret>>' end; W.update(0.4, 1)")
check("a scroll position that cannot be read keeps the arrow shown (the way back is never taken away)", seen(tb2))
run("W.cf2.GetScrollOffset = nil; W.update(0.4, 1)")
run("ns.chat2.toBottom = 'HIDE'; C.Refresh(); W.flush(); W.update(0.4, 1)")
check("Back-to-newest arrow: Hidden keeps it hidden while scrolled up", tb2.IsShown(tb2) is False)
run("ns.chat2.toBottom = 'SHOW'; C.Refresh(); W.flush(); W.update(0.4, 1)")
check("Back-to-newest arrow: Shown again, scrolled up: seen", seen(tb2))
run("ns.chat2.scrollOwn = false; ns.chat2.scrollBar = 'SHOW'; C.Refresh(); W.flush(); W.update(0.4, 1)")
check("the game's scroll bar chosen: shown on the docked window", sb2.IsShown(sb2) is True)
check("the game's scroll bar chosen: the arrow is the game's again (its alpha and shown state, for its own fade)",
      tb2.IsShown(tb2) is True and tb2.GetAlpha(tb2) == 0, (tb2.IsShown(tb2), tb2.GetAlpha(tb2)))
run("ns.chat2.scrollOwn = true; ns.chat2.scrollBar = 'HIDE'; C.Refresh(); W.flush(); W.update(0.4, 1)")
check("own scroll bar again: the game's is hidden, the arrow shown while scrolled up", sb2.IsShown(sb2) is False and seen(tb2))

# Locate outlines the arrow you see (the selected tab's), not ChatFrame1's
run("C.Locate({ 'tobottom', 'scroll' }, 5)")
target = run("""for _, o in ipairs(W.objects()) do if o._kind == 'Frame' and o.label and o:IsShown() and o._pts[1]
  and tostring(o.label._text):find('^Back%-to%-newest arrow') then
  local t = o._pts[1][2]; return (t == W.cf2.ScrollToBottomButton and 'cf2') or (t == W.cf1.ScrollToBottomButton and 'cf1') or tostring(t) end end return 'none'""")
check("Show me where: the back-to-newest arrow outline is on the selected tab's arrow", target == "cf2", target)
run("C.LocateClear()")

# undocking a window gives it the game's own pieces back; docking it again hides them again
run("""local f = W.cf2
f.isDocked = nil; f:ClearAllPoints(); f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 900, 500)
SELECTED_DOCK_FRAME = W.cf1; SELECTED_CHAT_FRAME = W.cf1
C.Parts(); W.update(0.4, 1)""")
check("undocked ChatFrame2: its scroll bar and resize grip are back", sb2.IsShown(sb2) is True and rz2.IsShown(rz2) is True)
check("undocked ChatFrame2: its arrow is back on the window, at the game's anchor", run("return W.cf2.ScrollToBottomButton._pts[1][2] == W.cf2") is True and not inside(tb2, textA), rect(tb2))
check("undocked ChatFrame2: its arrow has the game's alpha again", tb2.GetAlpha(tb2) == 0, tb2.GetAlpha(tb2))
run("W.cf2.isDocked = 2; W.cf2:ClearAllPoints(); W.cf2:SetAllPoints(W.cf1); SELECTED_DOCK_FRAME = W.cf2; C.Parts(); W.update(0.4, 1)")
check("docked again: hidden again, the arrow back in the text area", sb2.IsShown(sb2) is False and inside(tb2, textA) and not overlap(tb2, ownBar))

run("ns.chat2.enabled = false; C.Refresh(); W.flush()")
check("Chat Panel off: ChatFrame2's scroll bar back", sb2.IsShown(sb2) is True)
check("Chat Panel off: ChatFrame2's arrow back at the game's anchor with the game's alpha",
      run("return W.cf2.ScrollToBottomButton._pts[1][2] == W.cf2") is True and tb2.GetAlpha(tb2) == 0 and tb2.IsShown(tb2) is True,
      (rect(tb2), tb2.GetAlpha(tb2), tb2.IsShown(tb2)))
run("ns.chat2.enabled = true; C.Refresh(); W.flush(); W.update(0.4, 1)")

# ---- 3. /xui chat whispers ----------------------------------------------------------------------------------------------------
def report():
    for k in list(W.printed.keys()): W.printed[k] = None
    run("C.Command('whispers')")
    return "\n".join(str(v) for v in W.printed.values() if v)
out = report()
check("whispers: the game's setting is named", '"New Tab" (whisperMode popout)' in out, out)
check("whispers: the game's whisper manager is listening", "listens for whispers: yes; for Battle.net whispers: yes" in out, out)
check("whispers: none yet -> says so", "no whisper since the last /reload" in out, out)
run("W.fireEvent('CHAT_MSG_WHISPER', 'hi', 'Bobby-Realm'); W.fireEvent('CHAT_MSG_BN_WHISPER', 'yo', '<<secret>>')")
out = report()
check("whispers: received whispers are counted", "2 whispers received, 0 sent, 0 whisper tabs opened" in out, out)
check("whispers: arrived but no tab opened -> asks for the report and Lua errors", "the game opened no tab" in out, out)
check("whispers: no sender name is printed", "Bobby" not in out, out)
run("""FCF_OpenTemporaryWindow("WHISPER", "<<secret>>")
local f = W.new("ScrollingMessageFrame", "ChatFrame11", UIParent)
f.isTemporary, f.inUse, f.chatType, f.isDocked = true, true, "WHISPER", 3
CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame11"
GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES[#GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES + 1] = f""")
out = report()
check("whispers: a tab the game opened is counted, and found in the tab row", "1 whisper tabs opened" in out and "whisper windows now: 1 in the tab row, 0 floating; windows in the tab row: 3" in out, out)
check("whispers: no 'opened no tab' line once a tab exists", "the game opened no tab" not in out, out)
run("W.cvars.whisperMode = 'inline'")
out = report()
check("whispers: In-line -> points to the game's setting", '"In-line"' in out and "New Whispers > New Tab" in out, out)
run("W.cvars.whisperMode = '<<secret>>'")
out = report()
check("whispers: an unreadable setting is shown as unreadable, never guessed", "New Whispers is unreadable" in out, out)
run("FloatingChatFrameManager:UnregisterEvent('CHAT_MSG_WHISPER')")
out = report()
check("whispers: a manager that stopped listening is reported", "listens for whispers: no" in out, out)
for k in list(W.printed.keys()): W.printed[k] = None
run("C.Command('')")
help_ = " ".join(str(v) for v in W.printed.values() if v)
check("whispers: listed in /xui chat's help", "whispers" in help_, help_)

check("no module errors at the end", len(list(C.errors.keys())) == 0, dict(C.errors))
print("\nFAILS: %d" % fails)
sys.exit(1 if fails else 0)
