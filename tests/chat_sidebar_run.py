# The chat sidebar, QoL > Improved Chat > Sidebar (XayaUI_Chat 0.6.35, core 0.6.68; REQUEST-LOG UI-3, UI-17, A16 CR-4 / CR-6 / CR-7).
# Her words: "privacy bar should exist in a chat sidebar option that can be set to have a background or none at all. this bar should be
# configurable to be show on mouseover, auto-hide, etc and the buttons nested within should inherit that behavior. the sidebar should also be
# moveable to top, bottom, left or right sides and influence chat placement appropriately if it clips into the chat data panel or the end of
# the screen"; "left, but default chat size should be untouched -- only modify if the user sets a specified width for the whole chat
# container (including sidebar)"; her answers: "Fade and auto hide in combat both tick boxes"; buttons "Privacy cover, Blizzard chat
# buttons, History + window list, Scroll to bottom, Any other chat-based icon (can be minimap icons ...; default to having sidebar on if
# minimap is turned off)"; eye "Moves into sidebar"; fresh install "On with same opacity as chat pane with an additional layer underneath
# the black using the primary class color for tinting"; icons "XayaUI's own first".
# Checks in the stand-in world (tests/chat_world.lua; not the game). Negative control (V1): every check except the guards fails on
# Chat 0.6.34 (39cc9b8).
# Run: python3 tests/chat_sidebar_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1

PRE = r'''
local W = ...
local ns = W.ns
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
UnitClass = function() return "Mage", "MAGE", 8 end
for _, n in ipairs({ "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }) do
  local b = CreateFrame("Button", n, ChatFrame1ButtonFrame); b:SetSize(20, 20); b:SetPoint("TOP", ChatFrame1ButtonFrame, "TOP", 0, 0); b:Show()
end
ChatFrameToggleVoiceMuteButton:Hide()   -- the game shows the voice buttons only in a voice channel
W.over = {}
MouseIsOver = function(f) return W.over[f] and true or false end
InCombatLockdown = function() return W.combat and true or false end
ns.Merge = ns.Merge or function(t, d) for k, v in pairs(d) do if t[k] == nil then t[k] = v end end end
Minimap = CreateFrame("Frame", "Minimap", UIParent); Minimap:SetSize(140, 140); Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
-- what the minimap button's art needs, not in the chat stand-in world
local p = W.proto
p.CreateMaskTexture = p.CreateMaskTexture or function(self) return self:CreateTexture() end
p.AddMaskTexture = p.AddMaskTexture or function() end
p.SetTexture = p.SetTexture or function(self, t) self._tex = t end
W.load("XayaUI/MinimapButton.lua")
'''
def world(saved=""):
    lua = LuaRuntime(unpack_returned_tuples=True)
    W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
    lua.execute(PRE.replace("local W = ...", "local W = W_"), ) if False else lua.eval("function(W, src) return assert(loadstring(src))(W) end")(W, PRE)
    if saved: lua.execute(saved)
    for f in ("Minimap_OnDBReady",):
        pass
    W.start()
    lua.eval("function(ns) if ns.Minimap_OnDBReady then ns.Minimap_OnDBReady() end end")(W.ns)
    run = lua.eval("function(W, src, ...) local f = assert(loadstring(src)); setfenv(f, setmetatable({ W = W, ns = W.ns, C = W.ns.Chat }, { __index = _G })); return f(...) end")
    return lua, W, (lambda src, *a: run(W, src, *a))

# ===== defaults, place, background, buttons ========================================================================================
lua, W, run = world()
r = run(r'''
local out = {}
local s = ns.chat2
local sb = C.Sidebar and C.Sidebar()
out.exists = sb ~= nil and sb:IsShown()
out.on, out.side = s.sbOn, s.sbSide
local cont, pane = W.rect(C.Container()), W.rect(C.Pane())
if sb then
  local r = W.rect(sb)
  out.place = { cont.l - (r.l + r.w), r.h - cont.h, r.b - cont.b, r.w }
end
out.paneW = pane.w; out.savedX = s.x; out.contL = cont.l
if sb then
  out.tintC = sb.tint._color; out.blackC = sb.black._color
  out.tintLayer = { sb.tint:GetDrawLayer() }; out.blackLayer = { sb.black:GetDrawLayer() }
end
-- buttons in order
local names = {}
local kids = {}
for _, k in ipairs({ "XayaUIChatPrivacyButton", "ChatFrameMenuButton", "ChatFrameChannelButton", "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "XayaUIChatHistoryButton", "XayaUIChatSidebarWindows", "XayaUIChatSidebarBottom", "XayaUIChatSidebarXayaUI" }) do
  local b = _G[k]
  if b and sb and b:GetParent() == sb and b:IsShown() then kids[#kids + 1] = { k, W.rect(b).b } end
end
table.sort(kids, function(a, b) return a[2] > b[2] end)
for _, k in ipairs(kids) do names[#names + 1] = k[1] end
out.order = table.concat(names, ",")
local dock, tabs = W.rect(GeneralDockManager), W.rect(C.TabsArea())
out.dockFull = (dock.l + dock.w) == (tabs.l + tabs.w)
return out
''')
check("on by default, on the left", r.exists and r.on is True and r.side == "LEFT", (r.exists, r.on, r.side))
P = r.place
check("  ...outside the chat block, 2 px left of it, as tall as the block, 26 px thick (22 px buttons)", P and abs(P[1] - 2) < 0.01 and abs(P[2]) < 0.01 and abs(P[3]) < 0.01 and P[4] == 26, list(P.values()) if P else None)
check("  ...the chat's own size is untouched (440 wide, the default) (guard)", r.paneW == 440, r.paneW)
check("  ...it would run off the screen at x 24, so the block moves in to 28; the saved place stays 24", r.contL == 28 and r.savedX == 24, (r.contL, r.savedX))
T, B = r.tintC, r.blackC
check("background: a class-colour layer (Mage) under the chat pane's black, both at the chat pane's opacity (55 %)",
      T and B and abs(T[1] - 0.25) < 0.01 and abs(T[2] - 0.78) < 0.01 and abs(T[4] - 0.55) < 0.01 and abs(B[1] - 0.02) < 0.01 and abs(B[4] - 0.55) < 0.01
      and r.tintLayer[2] < r.blackLayer[2], (list(T.values()) if T else None, list(B.values()) if B else None))
check("buttons top to bottom: privacy eye, Blizzard's menu, channels and the shown voice button, history, chat windows, newest message",
      r.order == "XayaUIChatPrivacyButton,ChatFrameMenuButton,ChatFrameChannelButton,ChatFrameToggleVoiceDeafenButton,XayaUIChatHistoryButton,XayaUIChatSidebarWindows,XayaUIChatSidebarBottom", r.order)
check("the tab row no longer keeps room for the history button", r.dockFull)

# button actions
r = run(r'''
local out = {}
local sel = ChatFrame1; sel._off = 12; sel.ScrollToBottom = function(self) self._off = 0 end
SELECTED_CHAT_FRAME = sel
W.click(XayaUIChatSidebarBottom); out.bottom = sel._off
local clicked = false
GeneralDockManager.overflowButton = CreateFrame("Button", nil, GeneralDockManager)
GeneralDockManager.overflowButton:SetScript("OnClick", function() clicked = true end)
W.click(XayaUIChatSidebarWindows); out.windows = clicked
return out
''')
check("Newest message scrolls the selected chat to its newest line", r.bottom == 0, r.bottom)
check("Chat windows opens the game's list of chat windows", r.windows is True)

# XayaUI's button: minimap shown -> not in the sidebar; minimap turned off -> in it; "Show it in: Chat sidebar" -> in it, off the minimap
r = run(r'''
local out = {}
local function inBar() local b = _G.XayaUIChatSidebarXayaUI; return b ~= nil and b:IsShown() and b:GetParent() == C.Sidebar() end
out.def = inBar()
ns.minimapDB.hide = true; ns.Minimap_Refresh(); W.flush(); out.hidden = inBar()
ns.minimapDB.hide = false; ns.minimapDB.where = "SIDEBAR"; ns.Minimap_Refresh(); W.flush()
out.sidebar = inBar(); out.mmShown = _G.XayaUIMinimapButton ~= nil and _G.XayaUIMinimapButton:IsShown()
local opt
for _, e in pairs(ns.BuildMinimapTab(function() end).args) do if e.name == "Show it in" then opt = e end end
out.opt = opt and table.concat(opt.sorting, ",") or ""
ns.minimapDB.where = "BOTH"; ns.Minimap_Refresh(); W.flush()
out.both = inBar() and _G.XayaUIMinimapButton:IsShown()
ns.minimapDB.where = nil; ns.Minimap_Refresh(); W.flush()
return out
''')
check("XayaUI's button: not in the sidebar while the minimap button shows (nothing chosen)", r["def"] is False, r["def"])
check("  ...in the sidebar when the minimap button is turned off (her default)", r.hidden is True)
check("  ...Settings > Minimap Button > Show it in: Minimap, Chat sidebar, Both", r.opt == "MINIMAP,SIDEBAR,BOTH", r.opt)
check("  ...Chat sidebar: in the sidebar and off the minimap", r.sidebar is True and r.mmShown is False, (r.sidebar, r.mmShown))
check("  ...Both: in both places", r.both is True)

# sides, the data panel, the whole width
r = run(r'''
local out = {}
local s = ns.chat2
local function R(o) local x = W.rect(o); return { l = x.l, b = x.b, w = x.w, h = x.h, r = x.l + x.w, t = x.b + x.h } end
s.x, s.y = 300, 300
s.sbSide = "RIGHT"; C.Refresh(); W.flush()
local c, b = R(C.Container()), R(C.Sidebar()); out.right = { b.l - c.r, b.h - c.h }
s.sbSide = "TOP"; C.Refresh(); W.flush()
c, b = R(C.Container()), R(C.Sidebar()); out.top = { b.b - c.t, b.w - c.w, b.h }
s.sbSide = "BOTTOM"; C.Refresh(); W.flush()
c, b = R(C.Container()), R(C.Sidebar()); out.bottom = { c.b - b.t, b.w - c.w }
s.x, s.y = 24, 10; C.Refresh(); W.flush()
c, b = R(C.Container()), R(C.Sidebar()); out.bottomClip = { b.b, c.b, s.y }
s.x, s.y = 300, 300; s.sbSide = "LEFT"; s.barOn, s.barSide = true, "LEFT"; C.Refresh(); W.flush()
c, b = R(C.Container()); local bar, sb = R(C.Bar()), R(C.Sidebar())
out.dataPanel = { bar.l - sb.r, (sb.r <= bar.l) }
s.barSide = "BOTTOM"; s.sbChatW = 600; C.Refresh(); W.flush()
out.whole = { R(C.Pane()).w, R(C.Sidebar()).w + 2 + R(C.Pane()).w }
s.sbChatW = 0; C.Refresh(); W.flush(); out.back = R(C.Pane()).w
return out
''')
check("Right: outside the block on its right, 2 px away, as tall as the block", abs(r.right[1] - 2) < 0.01 and abs(r.right[2]) < 0.01, list(r.right.values()))
check("Top: above the block, as wide as the block, 26 px tall", abs(r.top[1] - 2) < 0.01 and abs(r.top[2]) < 0.01 and r.top[3] == 26, list(r.top.values()))
check("Bottom: under the block, as wide as it", abs(r.bottom[1] - 2) < 0.01 and abs(r.bottom[2]) < 0.01, list(r.bottom.values()))
check("  ...near the screen's bottom (y 10) the block moves up so the sidebar stays on screen; the saved y stays 10",
      r.bottomClip[1] >= -0.01 and abs(r.bottomClip[2] - 28) < 0.01 and r.bottomClip[3] == 10, list(r.bottomClip.values()))
check("Chat Data Panel on the left: the sidebar is outside it, never over it", r.dataPanel[2] is True and abs(r.dataPanel[1] - 2) < 0.01, list(r.dataPanel.values()))
check("Width of the whole chat 600: chat pane + sidebar = 600 (UI-17)", r.whole[1] == 572 and r.whole[2] == 600, list(r.whole.values()))
check("  ...set back to 0: the chat's own width again", r.back == 440, r.back)

# showing: mouseover, fade with the chat, hide in combat; buttons inherit (children)
r = run(r'''
local out = {}
local s = ns.chat2
local sb = C.Sidebar()
s.sbShow = "MOUSEOVER"; C.Refresh(); W.flush(); W.update(0.2, 2)
out.away = sb:GetAlpha()
W.over[C.Container()] = true; W.update(0.2, 2); out.overChat = sb:GetAlpha(); W.over[C.Container()] = nil
W.over[sb] = true; W.update(0.2, 2); out.overBar = sb:GetAlpha(); W.over[sb] = nil
s.sbShow = "ALWAYS"; s.sbFade = true; C.Refresh(); W.flush()
C.fade = 0.3; C.ApplyAlpha(); out.faded = sb:GetAlpha(); C.fade = 1; C.ApplyAlpha()
s.sbFade = false; s.sbCombat = true; C.Refresh(); W.flush()
W.combat = true; W.fireEvent("PLAYER_REGEN_DISABLED"); out.combat = sb:IsShown()
W.combat = false; W.fireEvent("PLAYER_REGEN_ENABLED"); W.flush(); out.after = sb:IsShown()
s.sbCombat = false
out.eyeKid = XayaUIChatPrivacyButton:GetParent() == sb
local opt = {}
for k, v in pairs(ns.BuildImprovedChatTab(function() end).args.sidebar.args) do
  if type(v) == "table" and v.args then for k2, v2 in pairs(v.args) do opt[k2] = v2 end else opt[k] = v end
end
out.opts = (opt.side and table.concat(opt.side.sorting, ",") or "") .. "|" .. (opt.show and table.concat(opt.show.sorting, ",") or "") .. "|" ..
  tostring(opt.fade and opt.fade.name) .. "|" .. tostring(opt.combat and opt.combat.name) .. "|" .. tostring(opt.bg and opt.bg.name)
return out
''')
check("On mouseover: hidden with the mouse away", r.away == 0, r.away)
check("  ...shown with the mouse over the chat, or over the sidebar", r.overChat == 1 and r.overBar == 1, (r.overChat, r.overBar))
check("Fade with the chat: the sidebar fades with it", abs(r.faded - 0.3) < 0.01, r.faded)
check("Hide in combat: hidden in combat, back after", r.combat is False and r.after is True, (r.combat, r.after))
check("the eye button is a child of the sidebar, so it follows all of these (her: buttons inherit)", r.eyeKid is True)
check("settings: Side Left / Right / Top / Bottom; Show Always / On mouseover; Fade with the chat; Hide in combat; Background",
      r.opts == "LEFT,RIGHT,TOP,BOTTOM|ALWAYS,MOUSEOVER|Fade with the chat|Hide in combat|Background", r.opts)

# switched off: everything back
r = run(r'''
local out = {}
local s = ns.chat2
local sb = C.Sidebar()
for k in pairs({}) do end
local o = ns.BuildImprovedChatTab(function() end).args.sidebar
local on = o.args.on or (function() for _, v in pairs(o.args) do if v.args and v.args.on then return v.args.on end end end)()
on.set(nil, false); W.flush()
out.hidden = not sb:IsShown()
out.eyeBack = XayaUIChatPrivacyButton:GetParent() == UIParent and XayaUIChatPrivacyButton:IsShown()
out.blizzBack = ChatFrameMenuButton:GetParent() == ChatFrame1ButtonFrame
local evs = 0
for _, ob in ipairs(W.objects()) do if ob._events and (ob._events.PLAYER_REGEN_DISABLED or ob._events.PLAYER_REGEN_ENABLED) then evs = evs + 1 end end
out.events = evs
local dock, tabs = W.rect(GeneralDockManager), W.rect(C.TabsArea())
out.reserve = (tabs.l + tabs.w) - (dock.l + dock.w)
return out
''')
check("switched off: the sidebar is hidden", r.hidden is True)
check("  ...the eye button is back beside the chat", r.eyeBack is True)
check("  ...Blizzard's chat buttons are back in their own strip", r.blizzBack is True)
check("  ...its combat events are let go (V14)", r.events == 0, r.events)
check("  ...the history button's room in the tab row is back", abs(r.reserve - 22) < 0.01, r.reserve)
check("no module errors (guard)", len(list(run("return C.errors").keys())) == 0, dict(run("return C.errors")))

# ===== V14: saved off at login, nothing of it exists =================================================================================
lua, W, run = world("CueRulesDB.chat2 = { sbOn = false }")
check("saved off at login: no sidebar frame is made (V14)", run("return _G.XayaUIChatSidebar == nil") is True)
check("  ...Improved Chat off with the sidebar saved on: no sidebar either", (lambda: (run("ns.chat2.sbOn = true; ns.chat2.improvedOn = false; C.Refresh(); W.flush(); return _G.XayaUIChatSidebar == nil or not _G.XayaUIChatSidebar:IsShown()")))() is True)
print("FAILS: %d" % fails)
