# The chat tab row at one height (XayaUI_Chat 0.6.31; REQUEST-LOG A14 CHATREV-12).
# Xaya 2026-11-07 [screenshot: General and Combat Log lower than Guild, Self and the Talent whisper tab]: "chat is still not displaying tabs
# correctly -- I thought we said we would fix this". Her UI-4 answer (2026-11-06): "set all v-aligns to the same -- the ones that cannot be
# changed determine the rest".
# Cause: Blizzard lays the tab row out in two groups (FCFDock_UpdateTabs, FloatingChatFrame.lua, wow-ui-source live): static tabs
# (General, Combat Log) at the dock's BOTTOMLEFT; the others parented to the dock scroll frame's scroll child and anchored LEFT of it
# (0, -1), so centred on the scroll child. Chat 0.6.20 aligned the NAME inside each tab (tests/chat_tab_align_run.py), whose stand-in world
# gave every tab the same anchor; the tabs themselves still sat at two heights.
# This test stands in FCFDock_UpdateTabs with those anchors (the scroll child's height, 32, is a STAND-IN: its real height was not
# read from the game) and checks what the player sees: every docked tab's centre at the static tabs' centre, after the game lays the row
# out again (a new tab) too, and the same within half a point however often it runs (no drift).
# Negative control (V1): with C.AlignTabRow switched off in the same run, the dynamic tabs' centres differ from General's (the bug).
# Run: python3 tests/chat_tab_row_run.py   Needs: pip install lupa. Stand-in world: tests/chat_world.lua (not the game).
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

# Blizzard's tab-row lay-out (anchors only), before the Chat Panel starts so its hook is placed on it
lua.eval(r'''function(W)
  local dock = GeneralDockManager
  dock.scrollFrame = W.new("Frame", "GeneralDockManagerScrollFrame", dock)
  local child = W.new("Frame", "GeneralDockManagerScrollFrameChild", dock.scrollFrame)
  child._w, child._h = 300, 32
  child:SetPoint("TOPLEFT", dock.scrollFrame, "TOPLEFT", 0, 0)
  dock.scrollChild = child
  local function tabbed(i, static)
    local cf = _G["ChatFrame" .. i]
    if not cf then
      cf = W.new("ScrollingMessageFrame", "ChatFrame" .. i, UIParent); cf._w, cf._h = 430, 120
      local tab = W.new("Button", "ChatFrame" .. i .. "Tab", UIParent); tab._w, tab._h = 80, 32
      tab.Text = tab:CreateFontString("ChatFrame" .. i .. "TabText"); tab.Text:SetText("Tab" .. i)
      CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame" .. i
    end
    cf.isDocked, cf.isStaticDocked = i, static or nil
    return cf
  end
  dock.DOCKED_CHAT_FRAMES = { tabbed(1, true), tabbed(2, true), tabbed(4), tabbed(5) }
  FCFDock_UpdateTabs = function(d)
    local lastS, lastD
    for _, f in ipairs(d.DOCKED_CHAT_FRAMES) do
      local tab = _G[f:GetName() .. "Tab"]
      tab:ClearAllPoints()
      if f.isStaticDocked then
        tab:SetParent(d)
        if lastS then tab:SetPoint("LEFT", lastS, "RIGHT", 1, 0) else tab:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0) end
        lastS = tab
      else
        tab:SetParent(d.scrollChild)
        if lastD then tab:SetPoint("LEFT", lastD, "RIGHT", 1, 0) else tab:SetPoint("LEFT", d.scrollChild, "LEFT", 0, -1) end
        lastD = tab
      end
    end
    if lastS then
      d.scrollFrame:ClearAllPoints()
      d.scrollFrame:SetPoint("LEFT", lastS, "RIGHT", 0, 0)
      d.scrollFrame:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, -1)
    end
  end
end''')(W)
W.start()
ns = W.ns
C = ns.Chat
r = lua.eval(r'''function(W, C)
  local dock = GeneralDockManager
  local function mid(i) local t = _G["ChatFrame" .. i .. "Tab"]; return (t:GetTop() + t:GetBottom()) / 2 end
  local out = {}
  -- the bug, with the fix switched off
  local real = C.AlignTabRow
  C.AlignTabRow = function() return false end
  FCFDock_UpdateTabs(dock); C.StyleTabs()
  out.bugDiff = mid(4) - mid(1)
  C.AlignTabRow = real
  -- the fix
  FCFDock_UpdateTabs(dock); W.flush()
  out.g, out.c, out.a, out.b = mid(1), mid(2), mid(4), mid(5)
  -- a new whisper tab: the game lays the row out again
  local cf = W.new("ScrollingMessageFrame", "ChatFrame6", UIParent); cf._w, cf._h = 430, 120
  local tab = W.new("Button", "ChatFrame6Tab", UIParent); tab._w, tab._h = 80, 32
  tab.Text = tab:CreateFontString("ChatFrame6TabText"); tab.conversationIcon = true
  CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame6"; cf.isDocked = 6; cf.isTemporary = true
  dock.DOCKED_CHAT_FRAMES[#dock.DOCKED_CHAT_FRAMES + 1] = cf
  FCFDock_UpdateTabs(dock); C.StyleTabs(); W.flush()
  out.w = mid(6); out.g2 = mid(1)
  -- no drift: run both many times
  for _ = 1, 10 do FCFDock_UpdateTabs(dock); C.StyleTabs(); C.AlignTabRow() end
  out.drift = math.abs(mid(4) - mid(1))
  out.errors = next(C.errors)
  return out
end''')(W, C)
check("negative control: without the fix, a dynamic tab's centre differs from General's (the reported bug)", abs(r.bugDiff) > 0.5, r.bugDiff)
check("General, Combat Log, Guild-like and Self-like tabs: one centre height", max(abs(r.c - r.g), abs(r.a - r.g), abs(r.b - r.g)) < 0.5, (r.g, r.c, r.a, r.b))
check("a new whisper tab (the game lays the row out again): same height", abs(r.w - r.g2) < 0.5, (r.w, r.g2))
check("no drift after many lay-outs", r.drift < 0.5, r.drift)
check("no module errors", r.errors is None, r.errors)
print("FAILS: %d" % fails)
sys.exit(1 if fails else 0)
