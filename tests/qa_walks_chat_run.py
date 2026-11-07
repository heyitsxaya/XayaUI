# In-game QA walkthroughs for the old chat issues #210, #229 (items 1-4), #250, #296 (XayaUI_DevAssist 0.7.9; REQUEST-LOG A14,
# CHATREV-6). Xaya 2026-11-06: "ensure qa has a handler that can automatically generate an answer"; scope "For every issue here";
# how: "Pre-fill, I confirm".
# Runs every step of the four walkthroughs on the real XayaUI_Chat code in the stand-in world (tests/chat_world.lua, real anchor
# geometry; not the game), doing by script what the step asks the person to do (drag, resize), and checks:
#   - each step's own check gives Pass on the working Chat Panel;
#   - negative controls (V1): the same checks give Fail when the behaviour is broken (collapse that does nothing, a Blizzard border
#     piece left showing, a button strip over the chat, a chat that cannot reach the bottom edge, a panel that does not follow);
#   - the last step puts every changed setting back;
#   - pre-fill in the window: Accept shows the addon's verdict, records it only when clicked, keeps a typed note, and is absent on a
#     walkthrough without prefill and on a noVerdict step.
# Run: python3 tests/qa_walks_chat_run.py   Needs: pip install lupa.
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
R = lua.eval(r'''function(W, ns, C, root)
  _G.XayaUI_NS = _G.XayaUI_NS or ns
  XayaUIDevAssistDB = {}
  dofile(root .. "/XayaUI_DevAssist/QAWalk.lua")
  dofile(root .. "/XayaUI_DevAssist/QAWalks-chat.lua")
  local QA = XayaUI_DevQA
  local out = { names = {}, oks = {}, notes = {} }
  local function rec(name, ok, note) out.names[#out.names + 1] = name; out.oks[#out.oks + 1] = ok and true or false; out.notes[#out.notes + 1] = tostring(note) end
  local function step(id, i) return QA.walks[id].steps[i] end
  local function run(id, i) local st = step(id, i); if st.setup then st.setup() end; W.flush(); if st.check then return st.check() end; return true, "(no check)" end
  local function chk(id, i) W.flush(); return step(id, i).check() end
  local s = ns.chat2
  s.x, s.y, s.width, s.height, s.barOn, s.barSide, s.stripMode, s.collapsed = 300, 200, 440, 230, false, "BOTTOM", "HIDE", false
  C.Layout(); W.flush()
  local orig = {}; for k, v in pairs(s) do orig[k] = v end

  -- #210
  local id = "chat-210-mover-collapse"
  rec("#210 registered with pre-fill", QA.walks[id] and QA.walks[id].prefill == true)
  rec("#210 step 1: Chat Panel on, settings remembered", run(id, 1))
  local okM, nM = run(id, 2); rec("#210 step 2: the mover covers the chat block", okM, nM)
  local okNo = chk(id, 3); rec("#210 step 3 before any drag: Fail (nothing moved yet)", not okNo)
  s.x, s.y = s.x + 50, s.y + 30; C.Layout()          -- what the mover's drag-stop saves
  local ok3, n3 = chk(id, 3); rec("#210 step 3 after a drag: Pass", ok3, n3)
  s.width, s.height = s.width + 60, s.height + 20; C.Layout()
  local ok4, n4 = chk(id, 4); rec("#210 step 4 after a resize: Pass", ok4, n4)
  rec("#210 step 5: mover closed", run(id, 5))
  local ok6, n6 = run(id, 6); rec("#210 step 6: hidden with the arrow", ok6, n6)
  local ok7, n7 = run(id, 7); rec("#210 step 7: shown again", ok7, n7)
  -- negative control: an arrow that does nothing
  local realSet = C.SetCollapsed
  C.SetCollapsed = function() end
  local okBad = run(id, 6); rec("#210 negative: collapse that does nothing gives Fail", not okBad)
  C.SetCollapsed = realSet
  local ok8, n8 = run(id, 8); rec("#210 last step: settings put back", ok8, n8)
  rec("  ...place and size really back", s.x == orig.x and s.y == orig.y and s.width == orig.width and s.height == orig.height)

  -- #229 items 1-4
  id = "chat-229-pieces"
  rec("#229 step 1: panel on below the chat", run(id, 1))
  local okA, nA = chk(id, 2); rec("#229 step 2: arrow inside the panel, nothing over it", okA, nA)
  local okR, nR = run(id, 3); rec("#229 step 3: strip right of the chat", okR, nR)
  local okL, nL = run(id, 4); rec("#229 step 4: strip left of the chat", okL, nL)
  local okH, nH = run(id, 5); rec("#229 step 5: strip hidden", okH, nH)
  -- negative control: the strip placed over the chat
  s.stripMode = "RIGHT"; C.Layout(); W.flush()
  local bf = C.ButtonFrameOf(C.Main()); bf:ClearAllPoints(); bf:SetPoint("TOPLEFT", C.Container(), "TOPLEFT", 10, -10)
  rec("#229 negative: a strip over the chat gives Fail", not chk(id, 3))
  s.stripMode = "HIDE"; C.Layout()
  local okP, nP = chk(id, 6); rec("#229 step 6: panel as wide as the chat, under it", okP, nP)
  local okB, nB = run(id, 7); rec("#229 step 7: chat at the screen's bottom edge", okB, nB)
  -- negative control: the game's clamp back on
  local realClamped = C.Clamped
  C.Clamped = function() return true end
  rec("#229 negative: the game's clamp on gives Fail", not chk(id, 7))
  C.Clamped = realClamped
  rec("#229 last step: settings put back", run(id, 8))
  rec("  ...panel / strip / place really back", s.barOn == orig.barOn and s.stripMode == orig.stripMode and s.y == orig.y)

  -- #250
  id = "chat-250-collapse-size"
  rec("#250 step 1", run(id, 1))
  local okC, nC = run(id, 2); rec("#250 step 2: hidden, same size / place / parent / scale, no border pieces", okC, nC)
  local okE, nE = run(id, 3); rec("#250 step 3: shown again, same as before", okE, nE)
  -- negative controls: a border piece left showing; the panel resized on collapse
  run(id, 2)
  local tp = _G.ChatFrame1TopTexture; tp._xuiSuppressed = false; tp:Show()
  rec("#250 negative: a Blizzard border piece showing gives Fail", not chk(id, 2))
  tp._xuiSuppressed = true; tp:Hide()
  C.Bar():SetHeight(33)
  rec("#250 negative: the panel resized while hidden gives Fail", not chk(id, 2))
  C.SetCollapsed(false); C.Layout()
  rec("#250 last step", run(id, 4))

  -- #296
  id = "chat-296-panel-follows"
  rec("#296 step 1", run(id, 1))
  local okO, nO = chk(id, 2); rec("#296 step 2: one arrow at the panel's left end", okO, nO)
  local old = CreateFrame("Button", "XayaUIChatCollapse", UIParent); old:Show()
  rec("#296 negative: the old floating arrow showing gives Fail", not chk(id, 2))
  old:Hide()
  local okF, nF = run(id, 3); rec("#296 step 3: the panel follows the chat", okF, nF)
  -- negative control: a panel left behind
  local bar = C.Bar(); bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5, 5)
  rec("#296 negative: a panel left behind gives Fail", not chk(id, 3))
  C.Layout()
  local okS, nS = run(id, 4); rec("#296 step 4: reports the panel staying while the chat is hidden", okS, nS)
  rec("#296 step 5 is a question (noVerdict)", step(id, 5).noVerdict == true)
  run(id, 5)
  rec("#296 last step", run(id, 6))
  rec("no module errors", next(C.errors) == nil)

  -- CHATREV-10 / CHATREV-11 walkthroughs (Chat 0.6.31)
  C_CVar = { v = { whisperMode = "popout_and_inline", showTimestamps = "none" } }
  function C_CVar.GetCVar(n) return C_CVar.v[n] end; function C_CVar.SetCVar(n, x) C_CVar.v[n] = x; return true end
  TIMESTAMP_FORMAT_HHMM_24HR = "%H:%M "
  ns.OpenSettingsPage = ns.OpenSettingsPage or function() end
  ns.chat2.whisperSelect = true; C.Refresh(); W.flush()
  id = "chat-whisper-switch"
  local okW1, nW1 = chk(id, 1); rec("whisper walk step 1: option on, mode Both", okW1, nW1)
  C_CVar.v.whisperMode = "inline"
  rec("whisper walk negative: In-line gives Fail", not chk(id, 1)); C_CVar.v.whisperMode = "popout_and_inline"
  GENERAL_CHAT_DOCK = GENERAL_CHAT_DOCK or {}
  local sel = ChatFrame1
  FCFDock_GetSelectedWindow = function() return sel end
  rec("whisper walk negative: still on General gives Fail at step 2", not chk(id, 2))
  sel = { chatType = "WHISPER" }
  local okW2, nW2 = chk(id, 2); rec("whisper walk step 2: a whisper tab is selected", okW2, nW2)
  rec("whisper walk negative: on the whisper tab gives Fail at step 3", not chk(id, 3))
  sel = ChatFrame1
  rec("whisper walk step 3: back on General", chk(id, 3))
  id = "chat-settings-layout"
  local okS1, nS1 = run(id, 1); rec("layout walk step 1: Chat Panel = General, Chat Tabs, Layout (the look)", okS1, nS1)
  local okS2, nS2 = run(id, 2); rec("layout walk step 2: Improved Chat = General, Chat Data Panel, Filters, Sounds, Privacy, Sidebar (behaviour)", okS2, nS2)
  local okS3, nS3 = run(id, 3); rec("layout walk step 3: the whisper switch is on Improved Chat > General > Chat history", okS3, nS3)
  local okS4, nS4 = run(id, 4); rec("layout walk step 4: timestamps set", okS4, nS4)
  local okS5, nS5 = run(id, 5); rec("layout walk step 5: timestamps put back", okS5 and C_CVar.v.showTimestamps == "none", nS5)
  local realTree = ns.Service("chatDebug").Options
  ns.Service("chatDebug").Options = function() local t = realTree(); t.args.look = { type = "group", name = "Appearance", order = 1.5, args = {} }; return t end
  rec("layout walk negative: an Appearance part back gives Fail", not chk(id, 1))
  ns.Service("chatDebug").Options = realTree

  -- (Chat 0.6.33; UI-18 / UI-19 / UI-21) the two switches apart
  id = "chat-improved-split"
  local okI1, nI1 = run(id, 1); rec("split walk step 1: Chat Panel off, Improved Chat on: the block and Chat Data Panel around Blizzard's chat", okI1, nI1)
  local cbar = C.Bar(); cbar:Hide()
  rec("split walk negative: no Chat Data Panel under the chat gives Fail", not chk(id, 1)); C.Layout()
  local okI2, nI2 = run(id, 2); rec("split walk step 2: Chat Panel on, Improved Chat off: none of its pieces show", okI2, nI2)
  ns.chat2.improvedOn = true; C.Refresh(); W.flush()
  rec("split walk negative: Improved Chat back on gives Fail at step 2", not chk(id, 2))
  local okI3, nI3 = run(id, 3); rec("split walk last step: switches put back", okI3 and ns.chat2.enabled == true and ns.chat2.improvedOn ~= false, nI3)

  -- (Chat 0.6.34; UI-15) the input line's place
  id = "chat-input-position"
  local okN1, nN1 = run(id, 1); rec("input walk step 1: Top under the tabs", okN1, nN1)
  rec("input walk negative: Bottom gives Fail at step 1", (function() ns.chat2.inputPos = "BOTTOM"; C.Refresh(); W.flush(); local r = not chk(id, 1); ns.chat2.inputPos = "TOP"; C.Refresh(); W.flush(); return r end)())
  local okN2, nN2 = run(id, 2); rec("input walk step 2: Top above the tabs", okN2, nN2)
  local okN3, nN3 = run(id, 3); rec("input walk step 3: Free move, mover open", okN3 and C.unlocked, nN3)
  ns.chat2.inputX = (ns.chat2.inputX or 0) + 50
  rec("input walk negative: a saved place the line is not at gives Fail", not chk(id, 3)); C.Refresh(); W.flush()
  local okN4, nN4 = run(id, 4); rec("input walk last step: put back, mover closed", okN4 and not C.unlocked and C.InputPos() == "BOTTOM", nN4)

  -- (Chat 0.6.35; UI-3) the sidebar
  id = "chat-sidebar"
  local okB1, nB1 = run(id, 1); rec("sidebar walk step 1: on the left, eye in it", okB1, nB1)
  local eye = XayaUIChatPrivacyButton; eye:SetParent(UIParent)
  rec("sidebar walk negative: the eye not in the strip gives Fail", not chk(id, 1)); C.Refresh(); W.flush()
  MouseIsOver = function() return false end
  local okB2, nB2 = run(id, 2); W.update(0.2, 2); okB2, nB2 = chk(id, 2); rec("sidebar walk step 2: hidden with the mouse away", okB2, nB2)
  MouseIsOver = function() return true end; W.update(0.2, 2)
  rec("sidebar walk negative: the mouse over it gives Fail at step 2", not chk(id, 2)); MouseIsOver = nil
  local okB3, nB3 = run(id, 3); rec("sidebar walk step 3: on the right", okB3, nB3)
  local okB4, nB4 = run(id, 4); rec("sidebar walk step 4: out of combat, shown", okB4, nB4)
  local okB5 = run(id, 5); rec("sidebar walk last step: put back", okB5 and ns.chat2.sbCombat ~= true)

  -- (O-143) every icon fades with the chat
  id = "chat-fade-controls"
  run(id, 1)
  rec("fade walk negative: not faded yet gives Fail", not chk(id, 1))
  C.fade = 0; C.ApplyAlpha()
  local okF1, nF1 = chk(id, 1); rec("fade walk step 1: chat faded, no icon at full strength", okF1, nF1)
  XayaUIChatArrow:SetAlpha(1)
  rec("fade walk negative: a chevron left at full strength gives Fail", not chk(id, 1))
  C.fade = 1; C.ApplyAlpha()
  local okF2, nF2 = chk(id, 2); rec("fade walk step 2: back with the chat", okF2, nF2)
  local okF3 = run(id, 3); rec("fade walk last step: put back", okF3)

  -- #430 walkthrough
  id = "chat-position-box"
  rec("position walk step 1", run(id, 1))
  local okP2, nP2 = run(id, 2); rec("position walk step 2: box open and filled", okP2, nP2)
  local box = C.PositionBox()
  rec("position walk negative: X not typed yet gives Fail", not chk(id, 3))
  box.x:SetText("200"); box.x:GetScript("OnEnterPressed")(box.x)
  local okP3, nP3 = chk(id, 3); rec("position walk step 3: X 200", okP3, nP3)
  box.right:GetScript("OnClick")(box.right)
  local okP4, nP4 = chk(id, 4); rec("position walk step 4: one pixel right", okP4, nP4)
  IsShiftKeyDown = function() return true end; box.up:GetScript("OnClick")(box.up); IsShiftKeyDown = function() return false end
  local okP5, nP5 = chk(id, 5); rec("position walk step 5: Shift = 10 up", okP5, nP5)
  local okP6, nP6 = run(id, 6); rec("position walk last step: put back, mover closed", okP6 and not C.unlocked and not box:IsShown(), nP6)

  -- CHATREV-12 tab-row walkthrough: a docked tab moved off the line gives Fail, on the line Pass
  GeneralDockManager.DOCKED_CHAT_FRAMES = { ChatFrame1, ChatFrame2 }
  ChatFrame1.isStaticDocked, ChatFrame2.isStaticDocked = true, true
  id = "chat-tab-row"
  rec("tab-row walk: only static tabs -> asks for another tab (Fail)", not chk(id, 1))
  ChatFrame2.isStaticDocked = nil
  local t2 = ChatFrame2Tab; t2:ClearAllPoints(); t2:SetPoint("LEFT", ChatFrame1Tab, "RIGHT", 1, 6)
  rec("tab-row walk negative: a tab 6 px higher gives Fail", not chk(id, 1))
  t2:ClearAllPoints(); t2:SetPoint("LEFT", ChatFrame1Tab, "RIGHT", 1, 0)
  local okT, nT = chk(id, 1); rec("tab-row walk: tabs on one line give Pass", okT, nT)

  -- pre-fill in the window
  QA.Start("chat-210-mover-collapse")
  local Wn = QA.Window()
  rec("window: before Do it for me, step 1's verdict is Fail (settings not remembered yet)", Wn.accept:IsShown() and Wn.accept:GetText() == "Accept: Fail", Wn.accept:GetText())
  QA.DoSetup(); QA.RunCheck()
  rec("window: Accept offers the addon's verdict", Wn.accept:IsShown() and Wn.accept:GetText() == "Accept: Pass", Wn.accept:GetText())
  rec("window: nothing recorded before the click", QA.State().steps[1] == nil)
  QA.Accept()
  local r1 = QA.State().steps[1]
  rec("window: Accept records Pass with the addon's note", r1 and r1.r == "P" and r1.note:find("^addon: ") ~= nil, r1 and r1.note)
  Wn.note:SetText("my own note"); QA.RunCheck()
  local verdict = QA.State().suggest and QA.State().suggest.r
  QA.Accept()
  local r2 = QA.State().steps[2]
  rec("window: a typed note is kept on Accept", r2 and r2.note == "my own note" and r2.r == verdict, r2 and r2.note)
  -- a walkthrough without prefill: no Accept
  QA.Register("qa-test-plain", { title = "plain", steps = { { text = "x", check = function() return true, "fine" end } } })
  QA.Start("qa-test-plain"); QA.RunCheck()
  rec("window: no Accept on a walkthrough without pre-fill", not Wn.accept:IsShown())
  rec("window: plain walkthrough still says 'you still decide'", (Wn.check:GetText() or ""):find("you still decide", 1, true) ~= nil)
  -- a noVerdict step: no Accept
  QA.Start("chat-296-panel-follows"); for _ = 1, 4 do QA.Answer("S") end; QA.RunCheck()
  rec("window: no Accept on a question step (noVerdict)", not Wn.accept:IsShown())
  return out
end''')(W, ns, C, ROOT)
for i in range(1, len(R.names) + 1):
    check(R.names[i], R.oks[i], R.notes[i])
print("FAILS: %d" % fails)
sys.exit(1 if fails else 0)
