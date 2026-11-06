# Chat tab names at one height (XayaUI_Chat 0.6.20; REQUEST-LOG UI-2 / UI-4).
# Xaya 2026-11-06: "text differences between general / combat log / user created panes should not exist. make sure all align properly"
# [screenshot: "General" lower than Combat Log / Trade / Party / Guild / Self]; her answer: "set all v-aligns to the same -- the ones that
# cannot be changed determine the rest; colors inherit either addon override or inherit blizzard-assigned options".
# The tabs get Blizzard's own anchors (wow-ui-source 297d7aa = 12.1.5.70783):
#   - template tab (General, Combat Log, a tab made by "Create New Window"): ChatTabArtTemplate ButtonText CENTER 0, -5, 50 x 8
#     (FloatingChatFrame.xml:414-418); the art piece Left 16 x 32 at BOTTOMLEFT -2, 0 (FloatingChatFrame.xml:227-232);
#   - whisper window tab (FCF_OpenTemporaryWindow, FloatingChatFrame.lua:711-720): conversationIcon set, Text re-anchored
#     LEFT of chatTab.Left's RIGHT + 10, -6, left-justified.
#   - General's lower name in her screenshot: its cause was not found in XayaUI's or Blizzard's code. The test stands it in with a
#     lower anchor (CENTER 0, -9): a STAND-IN, not the game's cause.
# Checks what the player sees: every docked tab's name centre at the same height in its tab (the template's), the whisper tab's name
# still left-aligned where it was, colours unchanged by this, and the game's anchors given back when the Chat Panel goes off.
# Negative control (V1): the height check fails on Chat 0.6.18 (main 22abdeb), the guards pass there too.
# Run: python3 tests/chat_tab_align_run.py   Needs: pip install lupa. Stand-in world: tests/chat_world.lua (not the game).
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
res = lua.eval(r'''function(W, ns, C)
  local out = {}
  -- Blizzard's anchors on each tab (see the header); the tabs side by side in the dock
  local function blizz(i, tab, x)
    tab:ClearAllPoints(); tab:SetPoint("BOTTOMLEFT", GeneralDockManager, "BOTTOMLEFT", x, 0)
    local left = _G["ChatFrame" .. i .. "TabLeft"] or W.new("Texture", "ChatFrame" .. i .. "TabLeft", tab)
    tab.Left = left
    left:ClearAllPoints(); left:SetSize(16, 32); left:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", -2, 0)
    tab.Text:SetSize(50, 8); tab.Text:ClearAllPoints(); tab.Text:SetPoint("CENTER", tab, "CENTER", 0, -5)
    tab._xuiTextPts = nil   -- the stand-in's tabs had no anchors when the Chat Panel started; in the game they have these from creation
  end
  blizz(1, ChatFrame1Tab, 0);  ChatFrame1Tab.Text:SetText("General")
  blizz(2, ChatFrame2Tab, 80); ChatFrame2Tab.Text:SetText("Combat Log")
  -- General's lower name (STAND-IN for the unknown cause in her screenshot)
  ChatFrame1Tab.Text:ClearAllPoints(); ChatFrame1Tab.Text:SetPoint("CENTER", ChatFrame1Tab, "CENTER", 0, -9)
  -- a docked whisper window (FCF_OpenTemporaryWindow)
  local cf4 = W.new("ScrollingMessageFrame", "ChatFrame4", UIParent); cf4._w, cf4._h = 430, 120; cf4._id = 4; cf4.isDocked = 3
  local t4 = W.new("Button", "ChatFrame4Tab", UIParent); t4._w, t4._h = 80, 32; t4._id = 4
  t4.Text = t4:CreateFontString("ChatFrame4TabText"); t4.Text:SetText("Insivius")
  blizz(4, t4, 160)
  t4.conversationIcon = W.new("Texture", "ChatFrame4TabConversationIcon", t4)
  t4.Text:ClearAllPoints(); t4.Text:SetPoint("LEFT", t4.Left, "RIGHT", 10, -6)
  CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame4"
  local tabs = { ChatFrame1Tab, ChatFrame2Tab, t4 }
  local function mid(o) local r = W.rect(o); return r.b + r.h / 2 end
  local function off(tab) return mid(tab.Text) - mid(tab) end
  local wl0 = W.rect(t4.Text).l
  ns.chat2.tabsShow = true
  C.StyleTabs()
  out.o1, out.o2, out.o4 = off(ChatFrame1Tab), off(ChatFrame2Tab), off(t4)
  out.wl0, out.wl1 = wl0, W.rect(t4.Text).l
  out.tabH = W.rect(ChatFrame2Tab).h
  out.c1 = { ChatFrame1Tab.Text:GetTextColor() }
  -- styling again (every refresh does) changes nothing
  C.StyleTabs()
  out.again = (off(ChatFrame1Tab) == out.o1 and off(t4) == out.o4)
  -- Chat Panel off: the game's anchors back
  local okT = pcall(C.Teardown)
  out.okT = okT
  local p1 = { ChatFrame1Tab.Text:GetPoint(1) }
  local p4 = { t4.Text:GetPoint(1) }
  out.r1 = (p1[1] == "CENTER" and p1[2] == ChatFrame1Tab and p1[5] == -9 and ChatFrame1Tab.Text:GetNumPoints() == 1)
  out.r4 = (p4[1] == "LEFT" and p4[2] == t4.Left and p4[3] == "RIGHT" and p4[4] == 10 and p4[5] == -6)
  return out
end''')(W, ns, C)
o1, o2, o4 = res.o1, res.o2, res.o4
print("name centre minus tab centre: General %.1f, Combat Log %.1f, whisper tab %.1f (tab height %.0f)" % (o1, o2, o4, res.tabH))
check("every docked tab's name at the same height in its tab: General, Combat Log, a whisper window's tab",
      abs(o1 - o2) < 0.01 and abs(o4 - o2) < 0.01, (o1, o2, o4))
check("  ...the height is the one Blizzard's tab template gives (Combat Log's, 5 px below the tab's centre)", abs(o2 - (-5)) < 0.01, o2)
check("  ...the whisper tab's name stays left-aligned where the game put it (only its height changes) (guard)", abs(res.wl1 - res.wl0) < 0.01, (res.wl0, res.wl1))
check("  ...styling again changes nothing (guard)", res.again)
check("Chat Panel off: each name's own anchors come back (General's, the whisper tab's)", res.okT and res.r1 and res.r4, (res.okT, res.r1, res.r4))
errs = list(C.errors.keys())
check("no module errors (guard)", len(errs) == 0, dict(C.errors))
print("FAILS: %d" % fails)
