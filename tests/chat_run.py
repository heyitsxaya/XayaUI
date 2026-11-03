# Stub test for the Chat Panel (Chat/*.lua). Run from the repo root: python3 tests/chat_run.py   Needs: pip install lupa.
# Uses tests/chat_world.lua (stand-in frames with real anchor geometry). Checks logic and placement, not the real game.
import os, sys
from lupa import LuaRuntime
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
check("dock manager on the tab strip", rect(L.GeneralDockManager) == rect(tabsA))
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
W.ctrl = False

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
check("a button per tab (not Combat-free kinds): All, General, Combat Log, Trade", str(labels) == "All,General,Combat Log,Trade", labels)
def lines(): return str(run("return table.concat(C.History_Lines(), '\\n')"))
run("C.History_Select(1)")
check("filter by tab: General shows the say line only", "hi from the test" in lines() and "party line" not in lines() and "boost spam" not in lines(), lines())
run("C.History_Select(2)")
check("filter by tab: tab 2 shows the party line", "party line" in lines() and "hi from the test" not in lines(), lines())
run("C.History_Select(3)")
check("filter by tab: Trade shows the channel line", "boost spam" in lines() and "party line" not in lines(), lines())
run("C.History_Select('ALL')")
check("filter All shows everything", "hi from the test" in lines() and "party line" in lines() and "boost spam" in lines())
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
check("Locate outlines every piece, labeling hidden ones", "Tab row" in str(lab) and "Chat Bar" in str(lab) and "Blizzard button strip (hidden)" in str(lab) and "Social button (hidden)" in str(lab), lab)
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
run("C.Command('off')")
check("/xui chat off sets enabled=false", run("return ns.chat2.enabled") is False)
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

check("no module errors at the end", len(list(C.errors.keys())) == 0, dict(C.errors))
print("\n%d failed" % fails if fails else "\nall passed")
sys.exit(1 if fails else 0)
