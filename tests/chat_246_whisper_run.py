# Chat 0.6.31 (REQUEST-LOG A14 CHATREV-10 / CHATREV-11).
# CHATREV-11, Xaya 2026-11-07: "why is chat functionality still not placed correctly in its appropriate location?" / "read what I said in
# the note"; her #246 words, built as given: "general tab should have font options, color + display options, scroll and fade options";
# "Chat Tabs should be its own pane"; "Chat history likely belongs in the general tab options"; "Timestamp, copying, and links options
# also likely belong in general options".
# CHATREV-10: "creating new whisper tabs by sending a new message don't automatically shift to a new whisper window from general tab";
# her setting "Both"; her answer "Yes, as an option". The game selects a tab you start only with New Whispers = New Tab
# (FloatingChatFrameManager_OnEvent, wow-ui-source live); Whispers.lua does the same with Both.
# Checks (stand-in world, tests/chat_world.lua; not the game):
#   - the Chat Panel's parts: General, Chat Tabs, Layout, Chat Data Panel, Filters, Sounds, Privacy (no Appearance / Fade and hide /
#     History); General's sections in her order with her words; each moved control is there exactly once, and every control the old
#     parts had still exists somewhere (nothing dropped);
#   - Timestamps reads and writes the game's showTimestamps setting;
#   - the old part names still open the right page;
#   - #430: clicking the mover opens the X / Y box; typed values and the arrows (Shift = 10) move the chat, kept on screen; a drag's end
#     does not open it; it closes with the mover;
#   - whispers: Both + a tab the game just opened for a whisper you sent -> that tab is selected and faded in; not with New Tab (the
#     game does it), In-line, the option off, a reply in an existing tab, or an incoming whisper; V14: no event frame or hook while off.
# Negative control (V1): on Chat 0.6.27 the General / Chat Tabs parts and Whispers.lua do not exist: the first checks fail.
# Run: python3 tests/chat_246_whisper_run.py   Needs: pip install lupa.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("C_CVar = { v = { whisperMode = 'popout_and_inline', showTimestamps = 'none' } }; "
            "function C_CVar.GetCVar(n) return C_CVar.v[n] end; function C_CVar.SetCVar(n, x) C_CVar.v[n] = x; return true end; "
            "TIMESTAMP_FORMAT_NONE = 'None'; TIMESTAMP_FORMAT_HHMM = '%I:%M '; TIMESTAMP_FORMAT_HHMMSS = '%I:%M:%S '; "
            "TIMESTAMP_FORMAT_HHMM_24HR = '%H:%M '")
W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
fails = 0
def check(name, cond, extra=""):
    global fails
    print(("PASS " if cond else "FAIL ") + name + ((" :: " + str(extra)) if (extra != "" and not cond) else ""))
    if not cond: fails += 1

W.start()
ns = W.ns
C = ns.Chat
R = lua.eval(r'''function(W, ns, C)
  local out = { names = {}, oks = {}, notes = {} }
  local function rec(n, ok, note) out.names[#out.names + 1] = n; out.oks[#out.oks + 1] = ok and true or false; out.notes[#out.notes + 1] = tostring(note) end
  local o = ns.BuildChatTab(function() end)
  local parts = {}
  for k, v in pairs(o.args) do if type(v) == "table" and v.type == "group" then parts[#parts + 1] = { k, v.order or 0, v.name } end end
  table.sort(parts, function(a, b) return a[2] < b[2] end)
  local names = {}
  for _, p in ipairs(parts) do names[#names + 1] = p[3] end
  rec("parts in order: General, Chat Tabs, Layout, Chat Data Panel, Filters, Sounds, Privacy", table.concat(names, "|") == "General|Chat Tabs|Layout|Chat Data Panel|Filters|Sounds|Privacy", table.concat(names, "|"))
  local g = o.args.general
  local tabs = {}
  for k, v in pairs(g and g.args or {}) do if v.type == "group" then tabs[#tabs + 1] = { v.order or 0, v.name } end end
  table.sort(tabs, function(a, b) return a[1] < b[1] end)
  local tn = {}
  for _, t in ipairs(tabs) do tn[#tn + 1] = t[2] end
  rec("General's tabs, her words and order", table.concat(tn, "|") == "Font options|Color + display options|Scroll and fade options|Chat history|Timestamp, copying, and links", table.concat(tn, "|"))
  -- leaves: every control in the whole Chat Panel tree, by name
  local where, count = {}, {}
  local function walk(t, path)
    for k, v in pairs(t.args or {}) do
      if type(v) == "table" then
        if v.type == "group" then walk(v, path .. "/" .. k)
        elseif v.type ~= "header" and v.type ~= "description" then
          local n = type(v.name) == "string" and v.name or k
          count[n] = (count[n] or 0) + 1; where[n] = path
        end
      end
    end
  end
  walk(o, "chat")
  -- each control once among the parts that were rearranged (the Chat Data Panel, Sounds and Privacy have their own controls with the
  -- same names, such as "Background color", and per-block / per-tab rows repeat by design)
  local seen, dup = {}, {}
  local function walk2(t)
    for _, v in pairs(t.args or {}) do
      if type(v) == "table" then
        if v.type == "group" then walk2(v)
        elseif v.type ~= "header" and v.type ~= "description" and type(v.name) == "string" then
          if seen[v.name] then dup[#dup + 1] = v.name end; seen[v.name] = true
        end
      end
    end
  end
  for _, k in ipairs({ "general", "tabs", "layout", "filters" }) do walk2(o.args[k]) end
  rec("every control exists once in General, Chat Tabs, Layout and Filters", #dup == 0, table.concat(dup, ", "))
  local function under(n, part) return where[n] and where[n]:find("^chat/" .. part) ~= nil end
  local expect = {
    { "Font", "general/tab_fontHdr" }, { "Font size", "general/tab_fontHdr" },
    { "Draw a background", "general/tab_colorHdr" }, { "Input background", "general/tab_colorHdr" }, { "Show a hint in the empty input line", "general/tab_colorHdr" },
    { "Chat Panel scroll bar (slow scrolling)", "general/tab_scrollHdr" }, { "Back-to-newest arrow", "general/tab_scrollHdr" },
    { "Fade the chat when it is idle", "general/tab_scrollHdr" }, { "Fade old lines away", "general/tab_scrollHdr" }, { "Fade the Chat Data Panel too", "general/tab_scrollHdr" },
    { "Keep recent messages for the history window", "general/tab_histHdr" }, { "In-game whisper tabs", "general/tab_histHdr" },
    { "Battle.net whisper tabs", "general/tab_histHdr" }, { "Keep console lines in a Console tab", "general/tab_histHdr" },
    { "Timestamps", "general/tab_tsHdr" }, { "Make web addresses clickable", "general/tab_tsHdr" }, { "Link color", "general/tab_tsHdr" },
    { "Open the history window", "general/tab_tsHdr" }, { "Show the small history button at the end of the tab row", "general/tab_tsHdr" },
    { "Show the tab row", "tabs" }, { "Tab font", "tabs" }, { "Selected tab background", "tabs" }, { "Switch to a new whisper tab I start", "tabs" },
    { "Chat hidden (collapsed)", "layout" }, { "Width (pixels)", "layout" }, { "Hide repeated messages", "filters" },
  }
  local bad = {}
  for _, e in ipairs(expect) do if not under(e[1], e[2]) then bad[#bad + 1] = e[1] .. " @ " .. tostring(where[e[1]]) end end
  rec("each moved control is where her words put it", #bad == 0, table.concat(bad, "; "))
  rec("the combine box (Chat 0.6.26) moved with the whisper lists", where["Combine Battle.net and in-game whispers in the consolidated tab"] ~= nil and under("Combine Battle.net and in-game whispers in the consolidated tab", "general/tab_histHdr"), where["Combine Battle.net and in-game whispers in the consolidated tab"])
  -- timestamps: the game's own setting
  local ts
  local function find(t) for k, v in pairs(t.args or {}) do if k == "timestamps" then ts = v end; if type(v) == "table" and v.type == "group" then find(v) end end end
  find(o)
  local vals = ts and ts.values() or {}
  ts.set(nil, TIMESTAMP_FORMAT_HHMM_24HR)
  rec("Timestamps: lists None and the game's formats; picking one sets showTimestamps", vals.none == "None" and vals[TIMESTAMP_FORMAT_HHMM] ~= nil and C_CVar.v.showTimestamps == TIMESTAMP_FORMAT_HHMM_24HR and ts.get() == TIMESTAMP_FORMAT_HHMM_24HR, C_CVar.v.showTimestamps)
  ts.set(nil, "none")
  -- old addresses
  local got
  local realOpen = ns.OpenSettingsPage
  ns.OpenSettingsPage = function(...) got = table.concat({ ... }, ">") end
  C.OpenSettings("look"); local a = got
  C.OpenSettings("history"); local b = got
  C.OpenSettings("bar", "tab_blocksHdr"); local c = got
  ns.OpenSettingsPage = realOpen
  rec("old part names open General; the Chat Data Panel's own address is unchanged", a == "reskin>chatpanel>general" and b == "reskin>chatpanel>general" and c == "reskin>chatpanel>bar>tab_blocksHdr", tostring(a) .. " " .. tostring(b) .. " " .. tostring(c))

  -- whispers ------------------------------------------------------------------------------------------------------------------
  local s = ns.chat2
  local selected = {}
  FCF_SelectDockFrame = function(f) selected[#selected + 1] = f end
  FCF_FadeInChatFrame = function() end
  GENERAL_CHAT_DOCK = GENERAL_CHAT_DOCK or {}
  local docked = { ChatFrame1 }
  FCFDock_GetChatFrames = function() return docked end
  local function newWhisperWindow(kind)
    local f = CreateFrame("ScrollingMessageFrame", "QAWhisper" .. (#docked + 1), UIParent)
    f.isTemporary, f.chatType = true, kind
    docked[#docked + 1] = f
    FCF_OpenTemporaryWindow(kind, "x")   -- the game's call (its post-hooks run)
    return f
  end
  s.whisperSelect = false; C.Refresh(); W.flush()
  local hookedOff = false
  for _, h in ipairs(W.hookLog) do if h[2] == "FCF_OpenTemporaryWindow" then hookedOff = true end end
  rec("V14: option off, no whisper hook placed yet", C.on.whisperSelect ~= true)
  s.whisperSelect = true; C.Refresh(); W.flush()
  rec("option on: the part runs", C.on.whisperSelect == true)
  -- Both, you start a whisper: the game opens the tab, then the sent event
  C_CVar.v.whisperMode = "popout_and_inline"
  local f1 = newWhisperWindow("WHISPER")
  W.fireEvent("CHAT_MSG_WHISPER_INFORM"); W.flush()
  rec("Both: the new whisper tab you started is selected", selected[#selected] == f1, #selected)
  -- reply in that tab later: no new window, no switch
  local n = #selected
  W.now = W.now + 5
  W.fireEvent("CHAT_MSG_WHISPER_INFORM"); W.flush()
  rec("a reply where the tab already exists does not switch", #selected == n)
  -- an incoming whisper opens a tab: no switch (the game does not either)
  newWhisperWindow("WHISPER"); W.fireEvent("CHAT_MSG_WHISPER"); W.flush()
  rec("an incoming whisper's new tab is not selected", #selected == n)
  -- Battle.net
  W.now = W.now + 5
  local f2 = newWhisperWindow("BN_WHISPER"); W.fireEvent("CHAT_MSG_BN_WHISPER_INFORM"); W.flush()
  rec("Battle.net whisper you start: its new tab is selected", selected[#selected] == f2)
  -- New Tab: the game selects it itself (no second select from us)
  W.now = W.now + 5; n = #selected
  C_CVar.v.whisperMode = "popout"
  newWhisperWindow("WHISPER"); W.fireEvent("CHAT_MSG_WHISPER_INFORM"); W.flush()
  rec("New Tab: left to the game (no extra select)", #selected == n)
  -- option off
  W.now = W.now + 5
  C_CVar.v.whisperMode = "popout_and_inline"
  s.whisperSelect = false; C.Refresh(); W.flush()
  newWhisperWindow("WHISPER"); W.fireEvent("CHAT_MSG_WHISPER_INFORM"); W.flush()
  rec("option off: no switch", #selected == n and C.on.whisperSelect == false)
  s.whisperSelect = true; C.Refresh(); W.flush()
  -- #430 (from #229 item 5): "Clicking the chat box in mover mode should open exact X/Y entry + cardinal arrows"
  s.x, s.y = 300, 200; C.Layout()
  rec("V14: no position box before the mover is clicked", rawget(_G, "XayaUIChatPosition") == nil)
  C.ToggleMover()
  local mv = XayaUIChatMover
  mv:GetScript("OnMouseDown")(mv, "LeftButton"); mv:GetScript("OnMouseUp")(mv, "LeftButton")
  local box = C.PositionBox()
  rec("clicking the mover opens the position box with X and Y filled in", box and box:IsShown() and box.x:GetText() == "300" and box.y:GetText() == "200", box and box.x:GetText())
  box.x:SetText("120"); box.x:GetScript("OnEnterPressed")(box.x)
  box.y:SetText("45"); box.y:GetScript("OnEnterPressed")(box.y)
  rec("typed X / Y move the chat block there", s.x == 120 and s.y == 45 and math.abs(C.Container():GetLeft() - 120) < 0.5 and math.abs(C.Container():GetBottom() - 45) < 0.5, s.x .. "," .. s.y)
  box.right:GetScript("OnClick")(box.right); box.up:GetScript("OnClick")(box.up)
  rec("arrows move 1 pixel", s.x == 121 and s.y == 46, s.x .. "," .. s.y)
  IsShiftKeyDown = function() return true end
  box.left:GetScript("OnClick")(box.left); box.down:GetScript("OnClick")(box.down)
  IsShiftKeyDown = function() return false end
  rec("with Shift, 10 pixels", s.x == 111 and s.y == 36, s.x .. "," .. s.y)
  box.x:SetText("-50"); box.x:GetScript("OnEnterPressed")(box.x)
  rec("kept on screen (X below 0 becomes 0)", s.x == 0, s.x)
  box:Hide()
  mv:GetScript("OnMouseDown")(mv, "LeftButton"); mv:GetScript("OnDragStart")(mv); mv:GetScript("OnDragStop")(mv); mv:GetScript("OnMouseUp")(mv, "LeftButton")
  rec("the end of a drag does not open the box", not box:IsShown())
  mv:GetScript("OnMouseDown")(mv, "LeftButton"); mv:GetScript("OnMouseUp")(mv, "LeftButton")
  C.ToggleMover()
  rec("the box closes with the mover", not box:IsShown() and C.unlocked == false)
  s.x, s.y = 24, 90; C.Layout()
  rec("no module errors", next(C.errors) == nil, next(C.errors))
  return out
end''')(W, ns, C)
for i in range(1, len(R.names) + 1):
    check(R.names[i], R.oks[i], R.notes[i])
print("FAILS: %d" % fails)
sys.exit(1 if fails else 0)
