# V14 "off costs nothing" for XayaUI_Chat (Chat 0.6.14). Xaya, 2026-11-05: "anything that is disabled in the addon through a tick box
# should NEVER LOAD or contribute to performance cost / demand in any way". For every Chat feature with a switch: saved off at login,
# nothing of it exists, is registered or runs (no frame, no event, no OnUpdate, no hook, no chat filter, no code on a frame, a chat
# message or a print); switched on through its own settings switch it is made and works; switched off again it stops at once (hooks and
# the chat filter, which the game cannot take back, do no work).
# (Chat 0.6.43; PS-57, #480) the Chat Panel's settings switch now takes effect on reload: A10b checks nothing is made before it, and
# APPLY() applies it the way /xui chat on|off does, so the on / off code itself is still measured (tests/switch_reload_run.py: the reload).
# Uses tests/chat_world.lua (stand-in frames). XayaUI_Chat's own frames are the ones made after W.coreObjects; its hooks the ones after
# W.coreHooks. "Chat Panel code ran" is measured by wrapping the shared C.* functions every file calls through the table (C.On,
# C.Container, C.Frames, ...), plus the game calls C_AddOns.IsAddOnLoaded, UnitName and string.lower.
# Labels: "(works)" checks that a feature still works when switched on (or back); "(as before)" a fact that was already true; "(sanity)"
# no module errors. They pass on the old code too. Every other check is a cost check and fails on Chat 0.6.13 (b8017df).
# Run from the repo root: python3 tests/chat_off_costs_nothing_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1

# meters and helpers, installed in every world after its files have loaded (and before login)
PRELUDE = r'''
local W = ...
local ns, C = W.ns, W.ns.Chat
M = { api = 0, unitName = 0, lower = 0, chat = 0, by = {} }
C_AddOns = { IsAddOnLoaded = function() M.api = M.api + 1; return false end }
local un = UnitName
UnitName = function(...) M.unitName = M.unitName + 1; return un(...) end
local low = string.lower
string.lower = function(...) M.lower = M.lower + 1; return low(...) end
for _, k in ipairs({ "On", "Container", "Frames", "History_Console", "IsMe", "StyleInput", "Touch", "Schedule", "Parts", "Glued",
    "IsCollapsed", "Main", "Pane", "Bar", "ApplyAlpha", "Anchor" }) do
  local f = C[k]
  if f then C[k] = function(...) M.chat = M.chat + 1; M.by[k] = (M.by[k] or 0) + 1; return f(...) end end
end
local pr = ns.ChatPrivacy_Refresh
if pr then ns.ChatPrivacy_Refresh = function(...) M.chat = M.chat + 1; M.by.ChatPrivacy_Refresh = (M.by.ChatPrivacy_Refresh or 0) + 1; return pr(...) end end
function SNAP() return { api = M.api, unitName = M.unitName, lower = M.lower, chat = M.chat } end
function DELTA(a)
  local by = {}
  return { api = M.api - a.api, unitName = M.unitName - a.unitName, lower = M.lower - a.lower, chat = M.chat - a.chat }
end
function CHATOBJ()            -- every object XayaUI_Chat made
  local out = {}
  for i, o in ipairs(W.objects()) do if i > W.coreObjects then out[#out + 1] = o end end
  return out
end
function NFRAMES() return #CHATOBJ() end
function ONUPDATES()          -- XayaUI_Chat objects with an OnUpdate script set
  local n, names = 0, {}
  for _, o in ipairs(CHATOBJ()) do if o._scripts.OnUpdate then n = n + 1; names[#names + 1] = tostring(o._name or o._kind) end end
  return n, table.concat(names, ",")
end
function EVENTS()             -- events registered on XayaUI_Chat's frames
  local set, n, names = {}, 0, {}
  for _, o in ipairs(CHATOBJ()) do for e in pairs(o._events) do if not set[e] then set[e] = true; n = n + 1; names[#names + 1] = e end end end
  table.sort(names)
  return n, table.concat(names, ","), set
end
-- the Chat Panel's own whisper counters for /xui chat whispers (Core.lua; part of the Chat Panel, not of a switch below it): the one frame
-- listening to exactly the four whisper events. BUSEVENTS: chat message events every OTHER XayaUI_Chat frame listens to (the message bus
-- for history, tab sounds, whisper overrides and wake-on-message, and the Console tab's system messages).
local DIAG = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_BN_WHISPER = true, CHAT_MSG_BN_WHISPER_INFORM = true }
local function isDiag(o)
  local n = 0
  for e in pairs(o._events) do if not DIAG[e] then return false end; n = n + 1 end
  return n == 4
end
function BUSEVENTS()
  local set, names = {}, {}
  for _, o in ipairs(CHATOBJ()) do
    if not isDiag(o) then for e in pairs(o._events) do if e:find("^CHAT_MSG_") and not set[e] then set[e] = true; names[#names + 1] = e end end end
  end
  table.sort(names)
  return #names, table.concat(names, ",")
end
function DIAGFRAMES() local n = 0; for _, o in ipairs(CHATOBJ()) do if isDiag(o) then n = n + 1 end end; return n end
function HOOKS()              -- hooks XayaUI_Chat placed
  local names = {}
  for i = W.coreHooks + 1, #W.hookLog do names[#names + 1] = W.hookLog[i][2] end
  return #names, table.concat(names, ",")
end
function HOOKED(name) for i = W.coreHooks + 1, #W.hookLog do if W.hookLog[i][2] == name then return true end end return false end
function NFILTERS() local n = 0; for _, l in pairs(W.filters) do n = n + #l end; return n end
function THEMEL() return #ns.Theme._listeners - W.coreThemeListeners end
function FIND(name)            -- an option of the Chat Panel's settings page, by its label (the switch Xaya clicks)
  local all = W.allChatOptions()
  for _, o in pairs(all.args) do if o.xuiSwitch and o.xuiSwitch.name == name then return o.xuiSwitch end end
  local o = all   -- (Chat 0.6.18, S1 #48: "Enable Chat Panel" is the row's tick box)
  local function walk(t)
    for _, v in pairs(t.args or {}) do
      if type(v) == "table" then
        if v.name == name then return v end
        local r = walk(v); if r then return r end
      end
    end
  end
  return walk(o)
end
function SET(name, v) local opt = FIND(name); assert(opt, "no option " .. name); opt.set({}, v); W.flush() end
-- (Chat 0.6.43; PS-57, #480) the settings switch takes effect on reload: this applies it the way a /xui chat command does (the hold let
-- go, one refresh), so the Chat Panel's own on / off code is still measured here; tests/switch_reload_run.py checks the reload itself
function APPLY(id) ns.SwitchApplyNow(id); C.Refresh(); W.flush() end
function SAY(msg, who) W.now = W.now + 1; W.fireEvent("CHAT_MSG_SAY", msg, who or "Hal-Realm", "", "", "", "", 0, 0, "", 0, math.random(1, 1e9)) end
'''

def world(saved_lua="", start=True):
    lua = LuaRuntime(unpack_returned_tuples=True)
    W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
    lua.eval("function(W, src) local f = assert(loadstring(src)); f(W) end")(W, PRELUDE)
    if saved_lua:
        lua.execute(saved_lua)
    def run(code, *args):
        return lua.eval("function(W, ns, C, ...) " + code + " end")(W, W.ns, W.ns.Chat, *args)
    def frames(seconds=1.0, fps=60):
        W.update(1.0 / fps, int(seconds * fps))
    if start:
        W.start()
    return lua, W, run, frames

def n(run, fn):
    r = run("return " + fn + "()")
    return r[0] if isinstance(r, tuple) else r
def both(run, fn):
    return run("return " + fn + "()")
def rect(W, o):
    r = W.rect(o); return (r.l, r.b, r.w, r.h)

# ===================================================================================================================================
# A. The Chat Panel saved OFF at login (and, since Chat 0.6.33, QoL > Improved Chat too: UI-18 / UI-19 / UI-21 made it a switch of its
#    own; with it on, its parts run over Blizzard's chat, tests/chat_improved_split_run.py)
# ===================================================================================================================================
lua, W, run, frames = world("CueRulesDB.chat2 = { enabled = false, improvedOn = false }", start=False)
check("A1 Chat Panel saved off, files read: XayaUI_Chat made no frame while loading", n(run, "NFRAMES") == 0, both(run, "ONUPDATES"))
check("A2 ...and placed no hook (no print hook, no whisper-tab hook)", n(run, "HOOKS") == 0, both(run, "HOOKS"))
check("A3 ...and added no theme callback", run("return THEMEL()") == 0, run("return THEMEL()"))
W.start()
check("A4 after login: no frame of the Chat Panel exists (no container, Chat Bar, privacy button, history button, drivers)",
      n(run, "NFRAMES") == 0, run("local t = {} for _, o in ipairs(CHATOBJ()) do t[#t+1] = tostring(o._name or o._kind) end return table.concat(t, ',')"))
check("A5 after login: no event is registered by XayaUI_Chat", n(run, "EVENTS") == 0, both(run, "EVENTS"))
check("A6 after login: OnUpdate scripts set by XayaUI_Chat: 0", n(run, "ONUPDATES") == 0, both(run, "ONUPDATES"))
check("A7 after login: no hook placed, no theme callback, no chat filter", n(run, "HOOKS") == 0 and run("return THEMEL()") == 0 and run("return NFILTERS()") == 0,
      (both(run, "HOOKS"), run("return THEMEL()"), run("return NFILTERS()")))
s0 = run("return SNAP()")
frames(1.0)
d = run("return DELTA(...)", s0)
check("A8 a second of frames (60) runs no Chat Panel code", d.chat == 0 and d.api == 0, (d.chat, d.api))
s0 = run("return SNAP()")
run("SAY('hello there'); W.fireEvent('CHAT_MSG_WHISPER', 'hi', 'Kai-R'); W.fireEvent('CHAT_MSG_SYSTEM', 'You are now Away: AFK'); print('an addon prints a line')")
d = run("return DELTA(...)", s0)
check("A9 a chat message, a whisper, a system message and a print() run no Chat Panel code", d.chat == 0 and d.unitName == 0 and d.lower == 0,
      (d.chat, d.unitName, d.lower, dict(run("return M.by"))))
keys = sorted(str(k) for k in run("return CueRulesDB.chat2").keys())
check("A10 no data built: the saved Chat Panel table holds only its switches (Chat Panel, Improved Chat)", keys == ["enabled", "improvedOn"], keys)
# switched on with its own settings switch, as Xaya would
run("SET('Enable Chat Panel', true)")
check("A10b switched on in the settings: nothing is made before the reload (PS-57)", n(run, "NFRAMES") == 0 and n(run, "EVENTS") == 0, both(run, "EVENTS"))
run("APPLY('chat.panel')")
W.update(0.4, 2)
check("A11 (works) switched on and applied: Blizzard's chat sits in the Chat Panel",
      run("return C.Container() ~= nil and C.Container():IsShown()") is True and rect(W, W.cf1) == rect(W, run("return C.TextArea()")))
ev_on = both(run, "EVENTS")
check("A12 (works) switched on: its refresh events and its upkeep are running", "PLAYER_ENTERING_WORLD" in str(ev_on[1]) and n(run, "ONUPDATES") >= 1,
      (ev_on, both(run, "ONUPDATES")))
check("A13 (works) switched on: its defaults are filled in", run("return ns.chat2.barOn == true and ns.chat2.width == 440") is True)
run("C.Main():SetAlpha(1); ChatFrame1Tab:SetAlpha(1)")
# off again
run("SET('Enable Chat Panel', false)")
run("APPLY('chat.panel')")
check("A14 (works) switched off again: Blizzard's chat is back where the game put it", rect(W, W.cf1) == (30.0, 40.0, 430.0, 120.0), rect(W, W.cf1))
check("A15 switched off again: no event registered, no OnUpdate set", n(run, "EVENTS") == 0 and n(run, "ONUPDATES") == 0,
      (both(run, "EVENTS"), both(run, "ONUPDATES")))
s0 = run("return SNAP()")
frames(1.0)
run("SAY('hello there'); SAY('hello there'); W.fireEvent('CHAT_MSG_SYSTEM', 'You are now Away: AFK'); print('an addon prints a line')")
d = run("return DELTA(...)", s0)
check("A16 switched off again: frames, chat messages, a system message and a print() run no Chat Panel code", d.chat == 0 and d.api == 0 and d.unitName == 0,
      (d.chat, d.api, d.unitName, dict(run("return M.by"))))
s0 = run("return SNAP()")
r = run("local out = {} for ev, list in pairs(W.filters) do for _, f in ipairs(list) do out[#out+1] = f(nil, ev, 'hello there https://x.org', 'Hal-Realm', '', '', '', '', 0, 0, '', 0, 5) end end return out")
d = run("return DELTA(...)", s0)
check("A17 switched off again: the chat filter the game keeps returns at once (no name read, no lower-case copy, no Chat Panel call)",
      all(v is False for v in r.values()) and d.chat == 0 and d.unitName == 0 and d.lower == 0, (list(r.values())[:3], d.chat, d.unitName, d.lower))
s0 = run("return SNAP()")
run("local eb = ChatFrame1EditBox; local f = eb:GetScript('OnEditFocusGained'); if f then f(eb) end; f = eb:GetScript('OnEditFocusLost'); if f then f(eb) end")
d = run("return DELTA(...)", s0)
check("A18 switched off again: opening the chat no longer restyles the hidden input strip (edit-box focus hooks idle)",
      run("return M.by.StyleInput") in (None, 0) or d.chat == 0, (d.chat, dict(run("return M.by"))))
run("ChatFrame1Tab:SetAlpha(0.4)")
check("A19 switched off again: the game's SetAlpha on a chat tab is not recorded by the Chat Panel", run("return ChatFrame1Tab._xuiBase") is None,
      run("return ChatFrame1Tab._xuiBase"))
run("SET('Enable Chat Panel', true); APPLY('chat.panel')"); W.update(0.4, 2)
run("C.SetCollapsed(true); C.SetCollapsed(false)")
check("A20 (works) back on, collapsed and shown again: the tab keeps the alpha the game gave it while the Chat Panel was off",
      abs(run("return ChatFrame1Tab:GetAlpha()") - 0.4) < 0.01, run("return ChatFrame1Tab:GetAlpha()"))
check("A21 (sanity) no module errors", len(list(run("return C.errors").keys())) == 0, dict(run("return C.errors")))

# ===================================================================================================================================
# B. The Chat Panel on, every feature with a switch saved OFF at login
# ===================================================================================================================================
ALL_OFF = """CueRulesDB.chat2 = { enabled = true, barOn = false, fadeOn = false, histOn = false, histConsole = false, soundsOn = false,
  whisperSoundsOn = false, spamRepeat = false, spamPhrases = '', links = false, ignoreClick = false, histButton = false, scrollOwn = false,
  inputHint = false, useTheme = false, whisperSelect = false, sbOn = false }
CueRulesDB.chat = { privBtn = false, privOn = false, privReveal = false }"""
lua, W, run, frames = world(ALL_OFF)
cnt, names = both(run, "ONUPDATES")
check("B1 every switch off: XayaUI_Chat has exactly one OnUpdate set, the Chat Panel's own upkeep (no Fade, Chat Bar, privacy driver)", cnt == 1, (cnt, names))
s0 = run("return SNAP()")
frames(1.0)
d = run("return DELTA(...)", s0)
check("B2 every switch off: a second of frames makes no C_AddOns.IsAddOnLoaded call", d.api == 0, d.api)
check("B3 Chat Bar off: no Chat Bar frame exists", run("return _G.XayaUIChatBar == nil and C.Bar() == nil") is True)
ev = both(run, "EVENTS")
check("B4 history, tab sounds, whisper overrides and wake-on-message off: no chat message event registered for them",
      n(run, "BUSEVENTS") == 0, both(run, "BUSEVENTS"))
# (Chat 0.6.20, REQUEST-LOG #81: /xui chat whispers and its counters are XayaUI Dev Assist's, which this test does not load; tests/
# devassist_debug_tools_run.py runs the report with it. Without it no frame of the Chat Panel listens to the whisper events.)
check("B4b without XayaUI Dev Assist no Chat Panel frame counts whispers (the /xui chat whispers counters are Dev Assist's)",
      n(run, "DIAGFRAMES") == 0, n(run, "DIAGFRAMES"))
# (Chat 0.6.31, CHATREV-10) "Switch to a new whisper tab I start": on registers exactly the two sent-whisper events, off none again
run("ns.chat2.whisperSelect = true; C.Refresh(); W.flush()")
check("B4c whisper-tab switch on: only the two sent-whisper events are registered for it",
      both(run, "BUSEVENTS") == (2, "CHAT_MSG_BN_WHISPER_INFORM,CHAT_MSG_WHISPER_INFORM"), both(run, "BUSEVENTS"))
run("ns.chat2.whisperSelect = false; C.Refresh(); W.flush()")
check("B4d whisper-tab switch off again: no chat message event registered", n(run, "BUSEVENTS") == 0, both(run, "BUSEVENTS"))
s0 = run("return SNAP()")
run("SAY('hello there'); W.fireEvent('CHAT_MSG_WHISPER', 'hi', 'Kai-R'); W.fireEvent('CHAT_MSG_PARTY', 'pull', 'Tank-R')")
d = run("return DELTA(...)", s0)
check("B5 ...so chat messages run no Chat Panel code (no name read, no lookups)", d.chat == 0 and d.unitName == 0, (d.chat, d.unitName, dict(run("return M.by"))))
check("B6 repeats, phrases and links off: no chat filter installed", run("return NFILTERS()") == 0, run("return NFILTERS()"))
check("B7 links and Ctrl + right-click off: SetItemRef not hooked", not run("return HOOKED('SetItemRef')"), both(run, "HOOKS"))
check("B8 Console tab off: print() not hooked and system messages not registered", not run("return HOOKED('print')") and "CHAT_MSG_SYSTEM" not in str(ev[1]),
      (both(run, "HOOKS"), ev))
check("B9 privacy button off: no privacy button frame", run("return _G.XayaUIChatPrivacyButton == nil") is True)
check("B10 history button off: no history button frame", run("return _G.XayaUIChatHistoryButton == nil") is True)
check("B11 (as before) Chat Panel scroll bar off: no scroll bar frame", run("return _G.XayaUIChatScrollBar == nil") is True)
run("W.hintText = 0; local h = C.hint; h.SetText = function(self, t) W.hintText = W.hintText + 1; self._text = t end; h.SetShown = function(self, v) W.hintText = W.hintText + 1; if v then self:Show() else self:Hide() end end")
frames(1.0)
check("B12 input hint off: the upkeep leaves the hint alone (no SetText / SetShown every 0.3 s)", run("return W.hintText") == 0, run("return W.hintText"))
s0 = run("return SNAP()")
run("for i = W.coreThemeListeners + 1, #ns.Theme._listeners do ns.Theme._listeners[i]() end; W.flush()")
d = run("return DELTA(...)", s0)
check("B13 'Use the XayaUI theme' off: a theme change makes the Chat Panel do nothing", d.chat == 0, (d.chat, dict(run("return M.by"))))
check("B14 (sanity) no module errors with every switch off", len(list(run("return C.errors").keys())) == 0, dict(run("return C.errors")))

# --- each switch on, then off again --------------------------------------------------------------------------------------------
base = n(run, "ONUPDATES")
run("SET('Fade the chat when it is idle', true); ns.chat2.fadeAfter = 2; ns.chat2.fadeTo = 0; C.Touch()")
check("B15 Fade on: its driver starts (one more OnUpdate)", n(run, "ONUPDATES") == base + 1, both(run, "ONUPDATES"))
W.mouseX, W.mouseY = -5, -5
W.update(0.5, 12)
pane = run("return C.Pane()")
check("B16 (works) Fade on: the chat fades out when idle", pane.GetAlpha(pane) < 0.05, pane.GetAlpha(pane))
run("SET('Fade the chat when it is idle', false)")
check("B17 Fade off again: its driver is gone (only the upkeep is left) and the chat is opaque at once", n(run, "ONUPDATES") == 1 and pane.GetAlpha(pane) > 0.99,
      (both(run, "ONUPDATES"), pane.GetAlpha(pane)))

run("SET('Show the Chat Data Panel', true)")
W.update(1.1, 2)
bar = run("return C.Bar()")
check("B18 Chat Bar on: built and shown, its ticker starts (one more OnUpdate)", bar is not None and bar.IsShown(bar) is True and n(run, "ONUPDATES") == base + 1,
      both(run, "ONUPDATES"))
txt = run("local t = {} for _, o in ipairs({ C.Bar():GetChildren() }) do for _, k in ipairs(o._kids or {}) do if k._text and k._text ~= '' then t[#t+1] = k._text end end end return table.concat(t, ' | ')")
check("B19 (works) Chat Bar on: its blocks show their text", "FPS" in str(txt), txt)
run("SET('Show the Chat Data Panel', false)")
check("B20 Chat Bar off again: hidden, its ticker gone (only the upkeep is left)", bar.IsShown(bar) is False and n(run, "ONUPDATES") == 1, both(run, "ONUPDATES"))

run("SET('Keep recent messages for the history window', true)")
ev = both(run, "BUSEVENTS")
h0 = run("return C.History_Count()")
run("SAY('kept line')")
check("B21 history on: the 18 chat message events are registered and a message is kept", ev[0] == 18
      and run("return C.History_Count()") == h0 + 1, (ev, h0, run("return C.History_Count()")))
run("SET('Keep console lines in a Console tab', true)")
c0 = run("return C.History_ConsoleCount()")
run("print('XayaUI: a printed line'); W.fireEvent('CHAT_MSG_SYSTEM', 'You are now Away: AFK')")
check("B22 (works) Console tab on: print() is hooked and printed lines and system messages are kept", run("return HOOKED('print')") is True
      and run("return C.History_ConsoleCount()") == c0 + 2, (run("return C.History_ConsoleCount()"), c0))
run("SET('Keep console lines in a Console tab', false)")
s0 = run("return SNAP()")
run("print('not kept'); W.fireEvent('CHAT_MSG_SYSTEM', 'You are no longer Away.')")
d = run("return DELTA(...)", s0)
check("B23 Console tab off again: system messages unregistered, the print hook does nothing (no Chat Panel code)",
      "CHAT_MSG_SYSTEM" not in str(both(run, "EVENTS")[1]) and d.chat == 0 and run("return C.History_ConsoleCount()") == c0 + 2,
      (both(run, "EVENTS"), d.chat, dict(run("return M.by"))))
run("SET('Keep recent messages for the history window', false)")
h1 = run("return C.History_Count()")
run("SAY('not kept either')")
check("B24 history off again: no chat message event registered for it, nothing kept", n(run, "BUSEVENTS") == 0 and run("return C.History_Count()") == h1,
      both(run, "BUSEVENTS"))

run("SET('Play tab sounds', true); ns.chat2.sounds[1] = { enabled = true, source = 'kit', value = '3081' }; for k in pairs(W.played) do W.played[k] = nil end")
ev = both(run, "BUSEVENTS")
run("SAY('hello')")
check("B25 tab sounds on: the 16 kinds a tab can show are registered and a message plays its tab's sound",
      ev[0] == 16 and "CHAT_MSG_WHISPER_INFORM" not in str(ev[1]) and [str(v) for v in run("return W.played").values()] == ["kit|3081"],
      (ev, list(run("return W.played").values())))
run("SET('Play tab sounds', false); SET('Use whisper sound overrides', true); ns.chat2.whisperSounds.list[1] = { who = 'kai', enabled = true, source = 'kit', value = '999' }")
ev = both(run, "BUSEVENTS")
run("for k in pairs(W.played) do W.played[k] = nil end; W.now = W.now + 1; W.fireEvent('CHAT_MSG_WHISPER', 'hi', 'Kai-R')")
check("B26 only whisper overrides on: only the two incoming whisper events are registered, and the override plays",
      str(ev[1]) == "CHAT_MSG_BN_WHISPER,CHAT_MSG_WHISPER" and [str(v) for v in run("return W.played").values()] == ["kit|999"],
      (ev, list(run("return W.played").values())))
run("SET('Use whisper sound overrides', false)")
check("B27 sounds off again: no chat message event registered for them", n(run, "BUSEVENTS") == 0, both(run, "BUSEVENTS"))

run("SET('Hide repeated messages', true)")
check("B28 (works) repeats on: the chat filter is installed (16 kinds)", run("return NFILTERS()") == 16, run("return NFILTERS()"))
f = run("return W.filters.CHAT_MSG_SAY[1]")
r1 = run("local f = ...; return f(nil, 'CHAT_MSG_SAY', 'buy my stuff', 'Spam-R', '', '', '', '', 0, 0, '', 0, 9001)", f)
r2 = run("local f = ...; return f(nil, 'CHAT_MSG_SAY', 'buy my stuff', 'Spam-R', '', '', '', '', 0, 0, '', 0, 9002)", f)
check("B29 (works) repeats on: the second identical message is hidden", (r1 is False or (isinstance(r1, tuple) and r1[0] is False)) and r2 is True, (r1, r2))
run("SET('Hide repeated messages', false)")
s0 = run("return SNAP()")
r3 = run("local f = ...; return f(nil, 'CHAT_MSG_SAY', 'buy my stuff', 'Spam-R', '', '', '', '', 0, 0, '', 0, 9003)", f)
d = run("return DELTA(...)", s0)
check("B30 repeats off again: the filter the game keeps returns at once (no name read, no lower-case copy)",
      r3 is False and d.unitName == 0 and d.lower == 0 and d.chat == 0, (r3, d.unitName, d.lower, d.chat))
run("SET('Make web addresses clickable', true)")
s0 = run("return SNAP()")
r4 = run("local f = ...; return f(nil, 'CHAT_MSG_SAY', 'see https://example.com now', 'Gus-R', '', '', '', '', 0, 0, '', 0, 9004)", f)
d = run("return DELTA(...)", s0)
check("B31 (works) links on: a web address is made clickable", isinstance(r4, tuple) and "|Haddon:XayaUI:url:" in str(r4[1]), r4)
check("B32 links on, repeats and phrases off: no name read and no lower-case copy for the spam check", d.unitName == 0 and d.lower == 0, (d.unitName, d.lower))
check("B33 (works) links on: the link-click hook is placed", run("return HOOKED('SetItemRef')") is True)
run("SET('Make web addresses clickable', false)")
s0 = run("return SNAP()")
run("W.ctrl = true; local n0 = #W.ignored; _G.SetItemRef('player:Spammer-Realm', 'x', 'RightButton'); W.ctrl = false; W.ign = #W.ignored - n0")
d = run("return DELTA(...)", s0)
check("B34 links and Ctrl + right-click off: a click on a name runs no Chat Panel code (hook idle) and ignores no one", run("return W.ign") == 0 and d.chat == 0,
      (run("return W.ign"), d.chat, dict(run("return M.by"))))
run("SET('Click a player\\'s name in chat to ignore them', true); W.ctrl = true; local n0 = #W.ignored; _G.SetItemRef('player:Spammer-Realm', 'x', 'RightButton'); W.ctrl = false; W.ign = #W.ignored - n0")
check("B35 (works) Ctrl + right-click on: it ignores that player", run("return W.ign") == 1)

run("SET('Show the toggle button beside the chat', true)")
pb = run("return _G.XayaUIChatPrivacyButton")
check("B36 (works) privacy button on: built and shown beside the chat", pb is not None and pb.IsShown(pb) is True and rect(W, pb)[0] >= sum(rect(W, run("return C.Container()"))[0:3:2]) - 0.01)
W.click(pb)
cover = run("return _G.XayaUIChatPrivacy")
check("B37 (works) clicking it covers the chat", cover is not None and cover.IsShown(cover) is True)
check("B38 'fades while the mouse is over it' off: the cover has no OnUpdate", run("return _G.XayaUIChatPrivacy._scripts.OnUpdate == nil") is True)
run("SET('Cover fades away while the mouse is over it', true)")
check("B39 (works) 'fades while the mouse is over it' on: the cover gets its OnUpdate, and the cover fades under the pointer",
      run("return _G.XayaUIChatPrivacy._scripts.OnUpdate ~= nil") is True and
      run("local c = _G.XayaUIChatPrivacy; local l, b, w, h = c:GetRect(); W.mouseX, W.mouseY = l + 5, b + 5; W.update(0.2, 2); local a = c:GetAlpha(); W.mouseX, W.mouseY = -5, -5; W.update(0.2, 2); return a") == 0)
run("SET('Cover fades away while the mouse is over it', false); SET('Cover the chat now', false); SET('Show the toggle button beside the chat', false)")
check("B40 privacy off again: button hidden, cover hidden with no OnUpdate", pb.IsShown(pb) is False and cover.IsShown(cover) is False
      and run("return _G.XayaUIChatPrivacy._scripts.OnUpdate == nil") is True)

run("SET('Show the small history button at the end of the tab row', true)")
hb = run("return _G.XayaUIChatHistoryButton")
check("B41 (works) history button on: built and shown", hb is not None and hb.IsShown(hb) is True)
run("SET('Show the small history button at the end of the tab row', false)")
check("B42 (works) history button off again: hidden", hb.IsShown(hb) is False)

run("SET('Chat Panel scroll bar (slow scrolling)', true)")
sb = run("return _G.XayaUIChatScrollBar")
check("B43 (works) scroll bar on: built and shown, with its OnUpdate", sb is not None and sb.IsShown(sb) is True and run("return _G.XayaUIChatScrollBar._scripts.OnUpdate ~= nil") is True)
run("SET('Chat Panel scroll bar (slow scrolling)', false)")
check("B44 scroll bar off again: hidden and its OnUpdate cleared", sb.IsShown(sb) is False and run("return _G.XayaUIChatScrollBar._scripts.OnUpdate == nil") is True)

run("SET('Show a hint in the empty input line', true)")
W.update(0.4, 2)
check("B45 (works) input hint on: the hint shows in the empty input line", run("return C.hint:IsShown()") is True and run("return W.hintText") > 0)
run("SET('Show a hint in the empty input line', false)")
check("B46 input hint off again: hidden at once", run("return C.hint:IsShown()") is False)
W.now += 4; W.update(0.1, 2)   # the outlines some switches flash ("Show me where") run out
check("B47 after every switch went on and off again: only the upkeep OnUpdate is left", n(run, "ONUPDATES") == 1, both(run, "ONUPDATES"))
check("B48 (sanity) no module errors after switching everything", len(list(run("return C.errors").keys())) == 0, dict(run("return C.errors")))

# ===================================================================================================================================
# C. The defaults (Chat Panel on, Fade off) and the drivers that only need to run while something happens
# ===================================================================================================================================
lua, W, run, frames = world("")
cnt, names = both(run, "ONUPDATES")
check("C1 defaults: OnUpdate scripts are the upkeep, the Chat Bar ticker and the scroll bar (3); no Fade or privacy driver", cnt == 3, (cnt, names))
s0 = run("return SNAP()")
frames(1.0)
d = run("return DELTA(...)", s0)
check("C2 defaults (Chat Panel on, Fade off): a second of frames makes no C_AddOns.IsAddOnLoaded call", d.api == 0, d.api)
run("SET('Play tab sounds', false); SET('Use whisper sound overrides', false)")
s0 = run("return SNAP()")
run("SAY('hello there')")
d = run("return DELTA(...)", s0)
check("C3 tab sounds and whisper overrides off (history on): a message reads no sender name for the sounds", d.unitName == 0, (d.unitName, dict(run("return M.by"))))
run("SET('Play tab sounds', true)")
s0 = run("return SNAP()")
run("SAY('hello again')")
d = run("return DELTA(...)", s0)
check("C4 tab sounds on but no tab has a sound: nothing is looked up for the sounds", d.unitName == 0, d.unitName)
run("C.Locate(nil, 3)")
cntL = n(run, "ONUPDATES")
W.now += 4
W.update(0.1, 2)
check("C5 'Show me where each piece is': its driver runs while outlines are up and stops when they are gone", cntL == 4 and n(run, "ONUPDATES") == 3,
      (cntL, both(run, "ONUPDATES")))
run("ns.chat2.useTheme = true; C.Refresh(); W.flush()")
s0 = run("return SNAP()")
run("for i = W.coreThemeListeners + 1, #ns.Theme._listeners do ns.Theme._listeners[i]() end; W.flush()")
d = run("return DELTA(...)", s0)
check("C6 (works) 'Use the XayaUI theme' on: a theme change refreshes the chat", d.chat > 0, d.chat)
check("C7 (sanity) no module errors", len(list(run("return C.errors").keys())) == 0, dict(run("return C.errors")))

# privacy "Cover the chat at every login" still covers the chat at login (moved from a loading-screen frame to the settings-ready step)
lua, W, run, frames = world("CueRulesDB.chat = { privStartHidden = true }")
cover = run("return _G.XayaUIChatPrivacy")
check("C8 (works) 'Cover the chat at every login': the chat is covered after login", cover is not None and cover.IsShown(cover) is True)

print("\nFAILS: %d" % fails)
sys.exit(1 if fails else 0)
