#!/usr/bin/env python3
"""XayaUI Chat's defaults reach the saved settings at login, in the game's load order (Debug chat defaults, Chat 0.6.46).

Found by the P5 worker (debug-log 2026-11-08-0233 settings-migration-p5): "in the game, the Sidebar's and privacy cover's defaults never
reach the saved settings at login. This includes sidebar fade by default (O-143)." Xaya's O-143 (2026-11-07): "weird chat appearance when
chat fades -- the sidebar icons should also be fading".

Cause: XayaUI_Chat/Core.lua filled the defaults from a copy taken at the end of Core.lua (C.defaultsAtLoad); Privacy.lua and Sidebar.lua
load after it, so their defaults were not in the copy, and C.EnsureDefaults' once-per-store guard stopped every later fill. The chat
stand-in (tests/chat_world.lua) cleared that copy before it opened the store, so every chat test ran with every default.

Checked in the whole-addon harness (tests/harness: every addon folder loaded from its .toc, files first, then the saved variables, then
ADDON_LOADED, as the game's loader does), over real /reloads (log out, the saved file written, a new session loads it):
  G  Fresh install: every Chat Panel / Sidebar default and every privacy cover default is in XayaUIChatDB at login with its value
     (sbOn, sbFade, sbSide, ... privR, privTexture, ...); what the player sees: with the chat fade on, the sidebar fades with the
     chat (Fade with the chat ticked on its settings page and in effect, V5 parity); the privacy cover draws its default colour.
  R  After /reload: the file written at logout holds them (saved, not defaulted again), and the second session changes nothing.
  E  An existing player (a file written by Chat 0.6.45, the player's own values, a saved false among them): every saved value is
     unchanged (deep-equal) after login and logout; only missing keys are added, each with its default; the saved sbFade = false
     keeps the sidebar at full strength while the chat fades; the cover draws the player's colour.
  M  A player from before P5 (settings only in CueRulesDB): copied unchanged into XayaUIChatDB, the missing defaults added,
     CueRulesDB untouched.
  O  V14: the Chat Panel and Improved Chat both saved off: nothing is added (as before).
  S  The stand-in (tests/chat_world.lua) and the game harness start from the same chat settings (V5).
  Q  The V22 walkthrough (Dev Assist 0.7.69, QA D29): part 1 reads the sidebar / privacy settings marked (d) defaulted at this login,
     the sidebar fade follows its tick (default and a saved false); part 2 after a real /reload reads them (s) saved; missing keys fail.
Negative control: G, R, E (added keys), M (defaults) and S fail on 1b974fe (Chat 0.6.45).
Run: python3 tests/chat_defaults_run.py   (Lua 5.1 via lupa)."""
import copy, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402
from lua51 import runtime as LuaRuntime  # noqa: E402
ROOT = os.path.abspath(os.path.join(HERE, ".."))

bad = n = 0


def check(name, ok, extra=""):
    global bad, n
    n += 1
    print(("PASS " if ok else "FAIL ") + name + ("" if ok or extra == "" else "  [%s]" % (extra,)))
    if not ok:
        bad += 1


# one session: log in, run SRC (returns a table of plain values), log out; returns (result, the saved files, Lua errors)
LOGIN = r'''
return function(W, L)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local ns = rawget(_G, "XayaUI_NS")
local C = ns.Service("chatDebug").C
local R = {}
local function copy(v) if type(v) ~= "table" then return v end local t = {} for k, x in pairs(v) do t[k] = copy(x) end return t end
R.defaults = copy(C.DEFAULTS)            -- every Chat file's defaults (Sidebar.lua's are in it)
R.sidebarDefaults = copy(C.SIDEBAR_DEFAULTS)
R.privacyDefaults = copy(ns.CHAT_DEFAULTS)
local db = rawget(_G, "XayaUIChatDB") or {}
R.atLogin = copy(db)
'''
OUTCOME = r'''
-- what the player sees: the chat fade turned on (as on Improved Chat's page), 6 s idle with the mouse away
local s = ns.chat2
if s and C.Sidebar() then
  local was = { s.fadeOn, s.fadeAfter, s.fadeTo, s.fadeSeconds }
  s.fadeOn, s.fadeAfter, s.fadeTo, s.fadeSeconds = true, 2, 0, 0.1
  C.Refresh(); W.tick(0.1, 60)
  R.fade = C.fade
  R.sidebarAlpha = C.Sidebar():GetAlpha()
  R.sidebarShown = C.Sidebar():IsShown()
  local g = C.Sidebar_Options(function() end, function() return ns.chat2 or {} end, function() end)
  R.pageFadeTick = g.args.fade.get()
  s.fadeOn, s.fadeAfter, s.fadeTo, s.fadeSeconds = was[1], was[2], was[3], was[4]   -- back as they were
  C.Refresh(); W.tick(0.1, 5)
end
-- the privacy cover, shown
if ns.ChatPrivacy_Set and ns.chatDB then
  local was = ns.chatDB.privOn
  ns.ChatPrivacy_Set(true); W.tick(0.1, 3)
  local cv = rawget(_G, "XayaUIChatPrivacy")
  local c = cv and cv.fill and cv.fill._color
  R.coverShown = cv and cv:IsShown() or false
  R.coverColor = c and { c[1], c[2], c[3] } or nil
  ns.ChatPrivacy_Set(was and true or false); W.tick(0.1, 3)
end
R.afterSession = copy(rawget(_G, "XayaUIChatDB") or {})
R.cue = copy(rawget(_G, "CueRulesDB") or {})
return R
end
'''


def session(saved, src=LOGIN + OUTCOME):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": H.to_lua(L, saved)}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    out, issues = loader.logout()
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return H.lua_to_py(res), H.lua_to_py(out), errs, len(issues)


def chatdb(saved):
    return ((saved or {}).get("XayaUI_Chat") or {}).get("XayaUIChatDB") or {}


def near(a, b):
    return isinstance(a, (int, float)) and isinstance(b, (int, float)) and abs(a - b) < 1e-6


def same(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return set(a) == set(b) and all(same(a[k], b[k]) for k in a)
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) and not isinstance(b, bool):
        return near(a, b)
    return a == b


def diff_keys(before, after):
    """keys whose value changed or vanished (must be none), and keys added"""
    changed = [k for k in before if k not in after or not same(before[k], after[k])]
    added = sorted(k for k in after if k not in before)
    return changed, added


errors = []

# --- G: fresh install -------------------------------------------------------------------------------------------------------
r1, saved1, e, iss = session({})
errors += e
D, SB, PD = r1["defaults"], r1["sidebarDefaults"], r1["privacyDefaults"]
c2, ch = (r1["atLogin"].get("chat2") or {}), (r1["atLogin"].get("chat") or {})
check("G guard: the Sidebar's defaults are among the Chat Panel's (Sidebar.lua adds them while it loads)", all(k in D for k in SB) and len(SB) >= 14)
for k in ("sbOn", "sbFade", "sbSide", "sbShow", "sbBg", "sbGap", "sbBtn", "sbPriv"):
    check("G fresh install: chat2.%s is in the saved settings at login with its default (%r)" % (k, SB.get(k)), k in c2 and same(c2[k], SB[k]), c2.get(k))
miss = sorted(k for k in D if k not in c2 or not same(c2[k], D[k]))
check("G fresh install: every Chat Panel / Improved Chat / Sidebar default is in chat2 with its value (%d keys)" % len(D), not miss, miss[:10])
for k in ("privR", "privG", "privB", "privTexture", "privBtnAlpha", "privMode", "privOn"):
    check("G fresh install: chat.%s (privacy cover) is in the saved settings at login with its default (%r)" % (k, PD.get(k)), k in ch and same(ch[k], PD[k]), ch.get(k))
miss = sorted(k for k in PD if k not in ch or not same(ch[k], PD[k]))
check("G fresh install: every privacy cover default is in chat with its value (%d keys)" % len(PD), not miss, miss[:10])
check("G guard: the chat faded out (fade on, 6 s idle)", isinstance(r1.get("fade"), (int, float)) and r1["fade"] < 0.02, r1.get("fade"))
check("G what she sees: the sidebar fades with the chat by default (O-143)", r1.get("sidebarShown") and isinstance(r1.get("sidebarAlpha"), (int, float)) and r1["sidebarAlpha"] < 0.02, (r1.get("sidebarShown"), r1.get("sidebarAlpha")))
check("G parity (V5): the settings page's \"Fade with the chat\" tick and what the sidebar does agree", (r1.get("pageFadeTick") is True) == (isinstance(r1.get("sidebarAlpha"), (int, float)) and r1["sidebarAlpha"] < 0.02), (r1.get("pageFadeTick"), r1.get("sidebarAlpha")))
cc = r1.get("coverColor")
check("G what she sees: the privacy cover draws its default colour", r1.get("coverShown") and cc and near(cc[0], PD["privR"]) and near(cc[1], PD["privG"]) and near(cc[2], PD["privB"]), (r1.get("coverShown"), cc))
check("G the saved file can be written by the game", iss == 0, iss)

# --- R: /reload ----------------------------------------------------------------------------------------------------------------
f1 = chatdb(saved1)
check("R the file written at logout holds sbFade / sbOn / sbSide (saved, not defaulted)", (f1.get("chat2") or {}).get("sbFade") is True
      and (f1.get("chat2") or {}).get("sbOn") is True and (f1.get("chat2") or {}).get("sbSide") == "LEFT", {k: (f1.get("chat2") or {}).get(k) for k in ("sbOn", "sbFade", "sbSide")})
check("R the file holds the privacy defaults", all(same((f1.get("chat") or {}).get(k), PD[k]) for k in PD), sorted(k for k in PD if not same((f1.get("chat") or {}).get(k), PD[k]))[:8])
r2, saved2, e, iss = session(copy.deepcopy(saved1))
errors += e
check("R after /reload: the second session reads the same chat settings at login (nothing added or changed)", same(r2["atLogin"], f1), diff_keys(f1.get("chat2") or {}, r2["atLogin"].get("chat2") or {}))
check("R after /reload: the sidebar still fades with the chat", isinstance(r2.get("sidebarAlpha"), (int, float)) and r2["sidebarAlpha"] < 0.02, r2.get("sidebarAlpha"))
check("R the second logout writes the same chat file", same(chatdb(saved2), f1))

# --- E: an existing player ------------------------------------------------------------------------------------------------------
# a file as Chat 0.6.45 wrote it: Core.lua's defaults filled, the Sidebar's and the privacy cover's missing, plus the player's own values
old_c2 = {k: v for k, v in D.items() if k not in SB}
old_c2.update({"sbFade": False, "sbSide": "RIGHT", "sbBg": False, "fadeOn": False, "bgA": 33, "barType2": "NONE", "histSize": 120,
               "sounds": {"WHISPER": {"source": "game", "value": "x"}},
               "whisperSounds": {"list": [{"who": "Friend", "enabled": True, "source": "game", "value": "y", "channel": "Master"}], "fav": {"enabled": False}}})
old_ch = {"privR": 1, "privG": 0.5, "privB": 0, "privBtnAlpha": 40, "privStartHidden": False, "privOn": False, "privCoverTabs": True}
existing = {"XayaUI_Chat": {"XayaUIChatDB": {"storeVersion": 1, "chat2": copy.deepcopy(old_c2), "chat": copy.deepcopy(old_ch)}}}
r3, saved3, e, iss = session(copy.deepcopy(existing))
errors += e
f3 = chatdb(saved3)
for part, before in (("chat2", old_c2), ("chat", old_ch)):
    changed, added = diff_keys(before, f3.get(part) or {})
    check("E existing player: every saved %s value is unchanged after login and logout (deep-equal)" % part, not changed, changed[:8])
    want = sorted(k for k in (D if part == "chat2" else PD) if k not in before)
    check("E existing player: only the missing %s keys were added (%d), each with its default" % (part, len(want)),
          added == want and all(same(f3[part][k], (D if part == "chat2" else PD)[k]) for k in added), (sorted(set(added) ^ set(want))[:8]))
check("E existing player: the saved sbFade = false stays false", (f3.get("chat2") or {}).get("sbFade") is False, (f3.get("chat2") or {}).get("sbFade"))
check("E what she sees: with her sbFade = false the sidebar stays at full strength while the chat fades", isinstance(r3.get("fade"), (int, float)) and r3["fade"] < 0.02
      and isinstance(r3.get("sidebarAlpha"), (int, float)) and r3["sidebarAlpha"] > 0.98, (r3.get("fade"), r3.get("sidebarAlpha")))
cc = r3.get("coverColor")
check("E what she sees: the privacy cover draws her colour (1, 0.5, 0)", cc and near(cc[0], 1) and near(cc[1], 0.5) and near(cc[2], 0), cc)
check("E nothing else in XayaUIChatDB changed", all(same(f3.get(k), v) for k, v in existing["XayaUI_Chat"]["XayaUIChatDB"].items() if k not in ("chat2", "chat")))

# (C.EnsureDefaults also makes the two sound tables, Sounds.lua's, when they are missing; they are not in C.DEFAULTS)
TABLES = {"sounds", "whisperSounds"}

# --- M: a player from before P5 (settings in CueRulesDB only) --------------------------------------------------------------------
pre_c2 = {"enabled": True, "improvedOn": True, "sbFade": False, "bgA": 20, "width": 500}
pre_ch = {"privR": 0.2, "privOn": False}
cue_before = {"version": 1, "ui": {"trayOpen": True, "advancedDebug": True}, "chat2": copy.deepcopy(pre_c2), "chat": copy.deepcopy(pre_ch)}
r4, saved4, e, iss = session({"XayaUI": {"CueRulesDB": copy.deepcopy(cue_before)}})
errors += e
f4 = chatdb(saved4)
changed, added = diff_keys(pre_c2, f4.get("chat2") or {})
check("M pre-P5 player: the old chat2 values are copied unchanged (sbFade = false kept)", not changed and f4.get("migratedFrom") == "CueRulesDB", (changed, f4.get("migratedFrom")))
check("M pre-P5 player: the missing defaults are added (the Sidebar's included)", sorted(added) == sorted((set(D) | TABLES) - set(pre_c2)), sorted(set(added) ^ ((set(D) | TABLES) - set(pre_c2)))[:8])
changed, added = diff_keys(pre_ch, f4.get("chat") or {})
check("M pre-P5 player: the old privacy values are copied unchanged, the missing privacy defaults added", not changed and sorted(added) == sorted(k for k in PD if k not in pre_ch), (changed, added[:5]))
cue4 = ((saved4.get("XayaUI") or {}).get("CueRulesDB") or {})
check("M CueRulesDB's chat settings are untouched (copy, never move)", same(cue4.get("chat2"), pre_c2) and same(cue4.get("chat"), pre_ch), (cue4.get("chat2"), cue4.get("chat")))

# --- O: V14, both chat switches saved off ----------------------------------------------------------------------------------------
off = {"XayaUI_Chat": {"XayaUIChatDB": {"storeVersion": 1, "chat2": {"enabled": False, "improvedOn": False, "sbFade": False}, "chat": {}}}}
r5, saved5, e, iss = session(copy.deepcopy(off), LOGIN + "\nR.on = {} for k, v in pairs(C.on) do if v then R.on[#R.on + 1] = k end end\nreturn R\nend\n")
errors += e
check("O V14: both chat switches saved off: nothing added to the saved settings, nothing of the chat runs",
      same(chatdb(saved5), off["XayaUI_Chat"]["XayaUIChatDB"]) and not r5.get("on"), (diff_keys(off["XayaUI_Chat"]["XayaUIChatDB"]["chat2"], chatdb(saved5).get("chat2") or {}), r5.get("on")))

# --- S: the stand-in starts where the game does --------------------------------------------------------------------------------
lua = LuaRuntime(unpack_returned_tuples=True)
W = lua.eval("function(root) return dofile(root .. '/tests/chat_world.lua')(root) end")(ROOT)
W.start()
sw = H.lua_to_py(lua.eval("function(ns) local function cp(v) if type(v) ~= 'table' then return v end local t = {} for k, x in pairs(v) do t[k] = cp(x) end return t end return { chat2 = cp(ns.chat2), chat = cp(ns.chatDB) } end")(W.ns))
for part in ("chat2", "chat"):
    a, b = sw.get(part) or {}, r1["atLogin"].get(part) or {}
    keys = sorted(set(a) ^ set(b)) + sorted(k for k in set(a) & set(b) if not same(a[k], b[k]))
    check("S parity (V5): the stand-in's %s at start equals the game harness's fresh install" % part, not keys, keys[:10])

# --- Q: the V22 walkthrough (XayaUI_DevAssist/QAWalks-debug-chatdefaults.lua), over a real /reload ---------------------------------
WALK = r'''
return function(W, L)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
local RV = QA and QA.Review
if RV and RV.Window and RV.Window() then RV.Window():Hide() end
ns.Print = function() end
local R = { has = QA and QA.walks[PART] ~= nil }
if not R.has then return R end
local C = ns.Service("chatDebug").C
if TAMPER then ns.Settings("chat").chat2.sbFade = false end
QA.Start(PART)
R.notes, R.verdicts = {}, {}
for i, st in ipairs(QA.walks[PART].steps) do
  if st.setup then QA.DoSetup(); W.tick(0.1, 60) end
  QA.RunCheck()
  local x = QA.State()
  R.notes[i] = x.seen and x.seen[i] and x.seen[i].d or ""
  R.verdicts[i] = x.seen and x.seen[i] and x.seen[i].a or ""
  if st.done then QA.Answer("D") elseif x.suggest then QA.Accept() else QA.Answer("P") end
end
local res = QA.DB().results[PART]
R.recorded = {}
for i, st in ipairs(res and res.steps or {}) do R.recorded[i] = st.r end
R.fadeOn = ns.Settings("chat").chat2.fadeOn
return R
end
'''


def walk(saved, part, tamper=False):
    src = WALK.replace("PART", repr(part)).replace("TAMPER", "true" if tamper else "false")
    return session(saved, src)


w1, wsaved, e, iss = walk({}, "debug-chatdefaults")
errors += e
check("Q the walkthrough is registered (Dev Assist 0.7.69)", w1.get("has") is True)
if w1.get("has"):
    nt, vd = w1["notes"], w1["verdicts"]
    check("Q part 1 step 1: the sidebar settings read back, each marked defaulted at this login (fresh install): Pass", vd[0] == "Y" and "sbFade=true(d)" in nt[0] and "sbSide=LEFT(d)" in nt[0] and "sbOn=true(d)" in nt[0], (vd[0], nt[0]))
    check("Q part 1 step 2: the privacy cover settings read back with their defaults: Pass", vd[1] == "Y" and "privRGB=0.04/0.04/0.06(d)" in nt[1] and "privTexture=UI-DialogBox-Background(d)" in nt[1], (vd[1], nt[1]))
    check("Q part 1 step 3: with the chat faded, the sidebar fades too (Fade with the chat, default): Pass", vd[2] == "Y" and "sidebar opacity 0.00" in nt[2], (vd[2], nt[2]))
    check("Q part 1: every step recorded (Accept / Done) and the fade settings put back", w1["recorded"] == ["P", "P", "P", "D"] and w1.get("fadeOn") is False, (w1["recorded"], w1.get("fadeOn")))
    w2, _, e, _ = walk(wsaved, "debug-chatdefaults-reload")
    errors += e
    nt2, vd2 = w2["notes"], w2["verdicts"]
    check("Q part 2 after the /reload: the sidebar settings now read (s) saved, as part 1 read them: Pass", vd2[0] == "Y" and "sbFade=true(s)" in nt2[0], (vd2[0], nt2[0]))
    check("Q part 2 after the /reload: the privacy settings now read (s) saved: Pass", vd2[1] == "Y" and "privBtnSize=28(s)" in nt2[1], (vd2[1], nt2[1]))
    # negative: the old game behaviour (Chat 0.6.45, no fill) reads as missing; and a sidebar that does not follow its tick fails
    w3, _, e, _ = session({}, WALK.replace("PART", repr("debug-chatdefaults")).replace("TAMPER", "false").replace(
        "local C = ns.Service(\"chatDebug\").C", "local C = ns.Service(\"chatDebug\").C\nfor k in pairs(C.SIDEBAR_DEFAULTS) do ns.Settings('chat').chat2[k] = nil end"))
    errors += e
    check("Q negative: with the Sidebar's settings missing (what Chat 0.6.45 left in the game) step 1 says MISSING: Fail", w3["verdicts"][0] == "N" and "sbFade=MISSING" in w3["notes"][0], (w3["verdicts"][0], w3["notes"][0]))
    w4, _, e, _ = walk({}, "debug-chatdefaults", tamper=True)
    errors += e
    check("Q her saved sbFade = false: step 3 expects the sidebar to stay at full strength, and it does: Pass", w4["verdicts"][2] == "Y" and "unticked" in w4["notes"][2] and "sidebar opacity 1.00" in w4["notes"][2], (w4["verdicts"][2], w4["notes"][2]))

for x in errors:
    print("ERROR in the game stand-in:", x[:600])
print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errors)))
sys.exit(1 if bad or errors else 0)
