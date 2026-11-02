# Stub test for Chat/Probe.lua (/xui chatprobe, Chat Panel rebuild stage S0): it must read only, survive broken frames,
# find the top-left floating button, find frames anchored to chat, and never record message text.
# Run from the repo root: python3 tests/chatprobe_run.py   Needs: pip install lupa. Stand-in frames; checks logic, not the real game.
import os
from lupa import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local allFrames = {}
local writes = 0
local function frame(kind, name, parent)
  local f = { _k = kind, _n = name, _par = parent, _kids = {}, _regs = {}, _pts = {}, _shown = true, _w = 100, _h = 20, _l = 500, _t = 500 }
  local M = {}
  function M:GetObjectType() return self._k end
  function M:GetName() return self._n end
  function M:GetDebugName() return self._n or (parent and ((parent._n or "?") .. ".child")) or "anon" end
  function M:IsShown() return self._shown end
  function M:IsVisible() return self._shown end
  function M:GetParent() return self._par end
  function M:GetSize() return self._w, self._h end
  function M:GetLeft() return self._l end
  function M:GetTop() return self._t end
  function M:GetAlpha() return 1 end
  function M:GetFrameStrata() return "MEDIUM" end
  function M:GetFrameLevel() return 3 end
  function M:GetNumPoints() return #self._pts end
  function M:GetPoint(i) local p = self._pts[i]; return p[1], p[2], p[3], p[4], p[5] end
  function M:GetChildren() return table.unpack(self._kids) end
  function M:GetRegions() return table.unpack(self._regs) end
  function M:GetText() return self._text end
  -- every writer counts: the probe must never call one
  for _, w in ipairs({ "SetPoint", "ClearAllPoints", "SetParent", "Show", "Hide", "SetAlpha", "SetSize", "SetWidth", "SetHeight", "SetFading", "SetMovable", "SetUserPlaced", "SetScript", "SetText" }) do
    M[w] = function() writes = writes + 1 end
  end
  setmetatable(f, { __index = M })
  if parent then parent._kids[#parent._kids + 1] = f end
  if name then _G[name] = f end
  allFrames[#allFrames + 1] = f
  return f
end
UIParent = frame("Frame", "UIParent"); UIParent._l, UIParent._t = 0, 1080
function UIParent:GetScale() return 1 end
function UIParent:GetEffectiveScale() return 0.75 end
GetScreenWidth = function() return 1920 end
GetScreenHeight = function() return 1080 end
GetCVar = function(k) return "1" end
GetBuildInfo = function() return "12.0.1", "99999", "Oct 1 2026", 120100 end
date = function() return "2026-11-02 23:59:00" end
NUM_CHAT_WINDOWS = 2
GetChatWindowInfo = function(i) return "Window" .. i, 14, 0, 0, 0, 1, true, false, true, false end
FCF_GetNumActiveChatFrames = function() return 1 end

local cf1 = frame("ScrollingMessageFrame", "ChatFrame1", UIParent)
cf1._pts = { { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 40 } }
cf1.IsMovable = function() return true end
cf1.GetNumMessages = function() return 3 end
cf1.GetMessageInfo = function() return "SECRET-CHAT-TEXT-DO-NOT-LOG" end
cf1.AddMessage = function() end
local tab = frame("Button", "ChatFrame1Tab", UIParent)
local eb = frame("EditBox", "ChatFrame1EditBox", cf1)
eb._pts = { { "TOPLEFT", cf1, "BOTTOMLEFT", 0, -2 } }
eb.GetAltArrowKeyMode = function() return false end
eb.GetAttribute = function() return "SAY" end
local bf = frame("Frame", "ChatFrame1ButtonFrame", UIParent)
bf._pts = { { "TOPRIGHT", cf1, "TOPLEFT", -2, 0 } }
local menu = frame("Button", "ChatFrameMenuButton", bf)
-- the floating "251" button: unnamed child of a named parent, top-left of the screen, text on a FontString
local social = frame("Button", "QuickJoinToastButton", UIParent)
social._l, social._t, social._w, social._h = 12, 1060, 30, 30
social._pts = { { "TOPLEFT", UIParent, "TOPLEFT", 12, -20 } }
local fs = frame("FontString", nil, nil); fs._text = "251"; fs._k = "FontString"
social._regs = { fs }
-- an anonymous frame in the top-left corner, anchored to the chat's button strip
local anon = frame("Frame", nil, UIParent); anon._l, anon._t = 100, 1000
anon._pts = { { "TOPLEFT", bf, "BOTTOMLEFT", 0, 0 } }
-- a hostile frame: every method throws
local bad = frame("Frame", "ChatFrame2", UIParent)
for _, k in ipairs({ "GetSize", "GetLeft", "GetTop", "GetNumPoints", "IsShown", "GetChildren", "GetRegions" }) do bad[k] = function() error("secret") end end
-- a frame in the middle of the screen: must NOT appear in the top-left list
frame("Frame", "Elsewhere", UIParent)

local idx = 0
local order = allFrames
EnumerateFrames = function(prev)
  if prev == nil then idx = 1 else
    for i, f in ipairs(order) do if f == prev then idx = i + 1 end end
  end
  return order[idx]
end

issecretvalue = function(v) return false end
canaccessvalue = function(v) return true end
C_Secrets = { HasSecretRestrictions = function() end, GetSpellAuraSecrecy = function() end }
ns = { printed = {} }
ns.Print = function(s) ns.printed[#ns.printed + 1] = s end
CueRulesDB = {}
_G.__writes = function() return writes end
local fn = assert(loadfile(__PATH__)); fn("XayaUI", ns)
'''.replace("__PATH__", "'" + os.path.join(ROOT, "Chat", "Probe.lua").replace("\\", "/") + "'"))
lua.execute(r'''
local fails, n = 0, 0
local function check(name, cond, extra) n = n + 1; if not cond then fails = fails + 1; print("FAIL: " .. name .. (extra and ("  -> " .. tostring(extra)) or "")) else print("ok:   " .. name) end end
local function has(pat) for _, l in ipairs(CueRulesDB.chatProbe.lines) do if l:find(pat, 1, true) then return l end end end
ns.ChatProbe()
local P = CueRulesDB.chatProbe
check("report is stored", P and type(P.lines) == "table" and #P.lines > 20, P and #P.lines)
check("stamped with a time", P.when == "2026-11-02 23:59:00")
check("READ ONLY: no writer method was called", __writes() == 0, __writes())
check("chat window 1 described with its anchor", has("ChatFrame1 [ScrollingMessageFrame]") and has("BOTTOMLEFT>UIParent:BOTTOMLEFT(20.0,40.0)"))
check("edit box anchor recorded (below the chat today)", has("TOPLEFT>ChatFrame1:BOTTOMLEFT(0.0,-2.0)"))
check("button strip tree lists its child", has("ChatFrameMenuButton"))
check("secret API presence recorded", has("issecretvalue=function") and has("C_Secrets functions: GetSpellAuraSecrecy, HasSecretRestrictions"))
check("message text is NEVER recorded", not has("SECRET-CHAT-TEXT"))
check("message length is recorded instead", has("last message length=27"))
check("suspect frame found by name", has("QuickJoinToastButton: QuickJoinToastButton [Button]"))
check("suspect that is absent says so", has("FriendsMicroButton: not found"))
check("top-left section lists the floating button with its text", has("QuickJoinToastButton [Button]") and has("text='251'"))
local inTop = false; local passed = false
for _, l in ipairs(P.lines) do
  if l:find("== shown frames in the top-left", 1, true) then inTop = true
  elseif inTop and l:find("Elsewhere", 1, true) then passed = true end
end
check("a mid-screen frame is not in the top-left list", not passed)
check("frames anchored to chat objects are found", has("shown=true -> ChatFrame1") or has("-> ChatFrame1ButtonFrame"))
check("a broken frame did not stop the probe", has("-- ChatFrame2"))
local printedTop = false
for _, s in ipairs(ns.printed) do if s:find("QuickJoinToastButton", 1, true) and s:find("top-left", 1, true) then printedTop = true end end
check("the chat line names the floating button right away", printedTop)
check("tells her to /reload to save", ns.printed[1] and ns.printed[1]:find("/reload", 1, true))
-- run twice: replaces, not appends
local first = #P.lines; ns.ChatProbe()
check("second run replaces the report", #CueRulesDB.chatProbe.lines == first)
-- no secrets API at all (older client): still runs
issecretvalue, canaccessvalue, C_Secrets = nil, nil, nil
ns.printed = {}; ns.ChatProbe()
check("works without the secrets API", CueRulesDB.chatProbe and #CueRulesDB.chatProbe.lines > 20 and not ns.printed[1]:find("failed", 1, true), ns.printed[1])
-- EnumerateFrames missing
EnumerateFrames = nil; ns.printed = {}; ns.ChatProbe()
check("works without EnumerateFrames", has("EnumerateFrames or screen size not available"))
print(n .. " checks, " .. fails .. " failed")
''')
