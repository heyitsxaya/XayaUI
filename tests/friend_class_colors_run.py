# Friend class colors in the friends list (XayaUI_Reskin 0.6.8; REQUEST-LOG CHAT-5). Xaya: "Under Blizzard reskins — what's the lift of
# implementing friend colors based on current class? If low, queue that up ...". Conservative default (session 014bN6tV7wcxBdJHNGwnMXZP):
# online friends only, offline keep Blizzard's grey, a tick box on the Blizzard UI Reskin tab, nothing hooked while off (V14).
# Checks with stand-ins for Blizzard's classic friends list (FriendsFrame_UpdateFriendButton, button.name, button.id / buttonType) and the
# documented FriendInfo / BNetAccountInfo structures (docs/reference/api/structures.md). Not the game.
# Negative control (V1): on main 7b830cf FriendColors.lua does not exist: the load check fails and no other check can run.
# Run: python3 tests/friend_class_colors_run.py   Needs: pip install lupa.
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
local W, root = ...
local ns = W.ns
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff3fc7eb" }, PRIEST = { r = 1, g = 1, b = 1, colorStr = "ffffffff" } }
FRIENDS_BUTTON_TYPE_WOW, FRIENDS_BUTTON_TYPE_BNET, BNET_CLIENT_WOW = 2, 3, "WoW"
local friends = {
  { connected = true, name = "Kaelan", guid = "Player-1-AAA", level = 80, className = "Mage" },
  { connected = false, name = "Oldpal", guid = "Player-1-BBB", level = 70, className = "Priest" },
}
C_FriendList = { GetFriendInfoByIndex = function(i) return friends[i] end }
GetPlayerInfoByGUID = function(g) if g == "Player-1-AAA" then return "Mage", "MAGE" elseif g == "Player-1-BBB" then return "Priest", "PRIEST" end end
C_BattleNet = { GetFriendAccountInfo = function(i)
  if i == 1 then return { gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Zyra", classFilename = "MAGE" } } end
  if i == 2 then return { gameAccountInfo = { isOnline = true, clientProgram = "App" } } end
end }
W.redraws = 0
FriendsList_Update = function() W.redraws = W.redraws + 1 end
-- Blizzard's row painter: sets the line, then (our hook) runs
function W.blizzLoad()
  FriendsFrame_UpdateFriendButton = function(button)
    if button.buttonType == 2 then local f = friends[button.id]; button.name:SetText(f.connected and (f.name .. ", Level " .. f.level .. " " .. f.className) or f.name)
    else button.name:SetText(button.id == 1 and "Anna |cff82c5ff(Zyra)|r" or "Ben") end
  end
end
function W.row(kind, id)
  local b = CreateFrame("Button", nil, UIParent); b.name = b:CreateFontString(); b.buttonType, b.id = kind, id
  FriendsFrame_UpdateFriendButton(b)
  return b.name:GetText()
end
assert(loadfile(root .. "/XayaUI_Reskin/FriendColors.lua"))("XayaUI_Reskin", ns)
'''
def world(saved):
    lua = LuaRuntime(unpack_returned_tuples=True)
    W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
    lua.execute(saved)
    ok = True
    try:
        W.root = ROOT
        lua.eval("function(W, root, src) return assert(loadstring(src))(W, root) end")(W, ROOT, PRE)
    except Exception as e:
        ok = str(e)
    W.start()
    lua.eval("function(ns) if ns.FireReady then ns.FireReady() end; if ns.SettingsOpenAllForTests then ns.SettingsOpenAllForTests() end end")(W.ns)   # (P5: and the module stores open) the login moment XayaUI core fires (Modules.lua)
    return lua, W, ok

# --- on (nothing saved) ----------------------------------------------------------------------------------------------------------
lua, W, ok = world("CueRulesDB = CueRulesDB or {}")
check("the file loads (guard: fails on main, where it does not exist)", ok is True, ok)
if ok is True:
    run = lua.eval("function(W, src) local f = assert(loadstring(src)); setfenv(f, setmetatable({ W = W, ns = W.ns }, { __index = _G })); return f() end")
    r = run(W, r'''
    local out = {}
    out.waitBeforeLoad = ns.FriendColors_Active()
    W.blizzLoad()
    for _, o in ipairs(W.objects()) do if o._events and o._events.ADDON_LOADED and o._scripts.OnEvent then o._scripts.OnEvent(o, "ADDON_LOADED", "Blizzard_FriendsFrame") end end
    out.wowOnline = W.row(2, 1); out.wowOffline = W.row(2, 2); out.bnet = W.row(3, 1); out.bnetApp = W.row(3, 2)
    local page = ns.FriendColors_Options(function() end)
    out.page = page.name; out.switch = page.xuiSwitch and page.xuiSwitch.name; out.tip = page.xuiSwitch and page.xuiSwitch.tip
    local r0 = W.redraws
    page.xuiSwitch.set(nil, false)
    -- (Reskin 0.6.23; PS-57, #480) the switch takes effect on reload: nothing changes before it; then the change is applied the way
    -- the reload's fresh start does for this part (the hold let go, its apply), so the off path itself is still checked here
    out.heldActive = ns.FriendColors_Active()
    ns.SwitchApplyNow("reskin.friendcolors"); ns.FriendColors_Apply()
    out.offRedraw = W.redraws > r0; out.offActive = ns.FriendColors_Active()
    out.wowOff = W.row(2, 1); out.saved = XayaUIReskinDB.friendColors.on
    -- the in-game walkthrough (V22, pre-fill): Do it for me switches it on and opens the list; the check counts re-colored rows
    _G.XayaUI_NS = ns; _G.XayaUIDevAssistDB = {}
    _G.ToggleFriendsFrame = function() W.row(2, 1); W.row(2, 2); W.row(3, 1) end
    dofile(W.root .. "/XayaUI_DevAssist/QAWalk.lua"); dofile(W.root .. "/XayaUI_DevAssist/QAWalks-friends.lua")
    local walk = XayaUI_DevQA.walks["friend-class-colors"]
    walk.steps[1].setup(); out.walk1, out.walk1note = walk.steps[1].check()
    out.prefill = walk.prefill
    ns.FriendColorsStats.colored = 0
    out.walkNeg = not walk.steps[1].check()
    walk.steps[2].setup(); out.walkBack = walk.steps[2].check() and XayaUIReskinDB.friendColors.on == false
    return out
    ''')
    check("on by default after login (nothing saved), waiting for Blizzard's friends list to load", r.waitBeforeLoad is True)
    check("an online character friend: the name in its class color, the rest as Blizzard wrote it", r.wowOnline == "|cff3fc7ebKaelan|r, Level 80 Mage", r.wowOnline)
    check("an offline character friend keeps Blizzard's text and grey", r.wowOffline == "Oldpal", r.wowOffline)
    check("a Battle.net friend in WoW: the (CharacterName) part in its class color", r.bnet == "Anna |cff82c5ff(|cff3fc7ebZyra|r)|r", r.bnet)
    check("a Battle.net friend in another game is left alone", r.bnetApp == "Ben", r.bnetApp)
    check("Blizzard UI Reskin > Friend Colors, its tick box on the row with a one-sentence hover",
          r.page == "Friend Colors" and r.switch == "Friend class colors" and str(r.tip).endswith(".") and str(r.tip).count(". ") == 0, (r.page, r.switch, r.tip))
    check("unticked: nothing changes before the reload (PS-57)", r.heldActive is True, r.heldActive)
    check("unticked and applied: the open list is redrawn and the hook does nothing (Blizzard's colors back); saved off",
          r.offRedraw and r.offActive is False and r.wowOff == "Kaelan, Level 80 Mage" and r.saved is False, (r.offRedraw, r.offActive, r.wowOff, r.saved))
    check("QA walkthrough (pre-fill): Do it for me turns it on and opens the list; the check passes with re-colored rows", r.prefill is True and r.walk1 is True, r.walk1note)
    check("  ...no re-colored row gives Fail (negative control)", r.walkNeg is True)
    check("  ...the last step puts the setting back (it was off)", r.walkBack is True)

# --- saved off at login: nothing made (V14) ----------------------------------------------------------------------------------------
lua, W, ok = world("CueRulesDB = { ui = { friendColors = { on = false } } }")
if ok is True:
    n = lua.eval("function(W) local n = 0; for _, o in ipairs(W.objects()) do if o._events and o._events.ADDON_LOADED then n = n + 1 end end; return n end")(W)
    check("saved off at login: no hook, no event, nothing waiting (V14)", n == 0 and lua.eval("function(ns) return ns.FriendColors_Active() end")(W.ns) is False, n)
else:
    check("saved off at login: no hook, no event, nothing waiting (V14)", False, ok)
print("FAILS: %d" % fails)
