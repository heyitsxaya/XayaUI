#!/usr/bin/env python3
"""Walkthroughs for UI overhaul switches, across real /reloads (XayaUI_DevAssist 0.7.53; issue #480; Xaya's standing rule, 2026-11-07:
"none of these should be toggleable without a reload -- this is the standing convention for all UI overhaul addons").
reskin-switches (E2e) and chat-improved-split (D25) are now three parts each: part 1 changes the switch and ends with a /reload; the
part after each reload reads the look. Here every /reload is a real one: the stand-in game logs out (the saved files are written)
and a new session loads the addons from those saved files, as the game does. Checked:
  - part 1 of the reskin walkthrough flips Enable Blizzard Reskin through the switch itself (saved, the reload question asked) and
    records the new value in its own saved result; the part 2 check before any /reload says "not reloaded yet" (no verdict);
  - after the /reload, part 2 reads the look (chat, Esc menu; the character window has no service that tells, so it is left to her)
    against the switch part 1 set: Pass; a look that does not follow the switch: Fail; part 2 flips the switch back; after the second
    /reload, part 3 finds it as it was before part 1 and the look following it (the Esc menu read once it was opened);
  - the chat walkthrough's part 1 only saves the switches (nothing applied before the /reload) and keeps your own in its result; after
    the /reload part 2 sees Blizzard's chat (no XayaUI art) with Improved Chat's pieces around it; after the second, part 3 sees the
    XayaUI art and none of Improved Chat's pieces; its last step saves your own switches back, and after one more /reload they are
    as they were before part 1;
  - no new saved key: XayaUIDevAssistDB keeps only the keys it had (results of runs under qa.results), CueRulesDB gains none.
Every check fails on Dev Assist 0.7.52 (one walkthrough per switch, applied at once, no parts).
Run: python3 tests/qa_walks_reload_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402
import re  # noqa: E402

# QA-branch modules: main keeps only core, Options, Rules, QoL, Bonus, Dev Assist, Media; Chat, Reskin and Nameplates live on the QA branch
ABSENT = [m for m in ("XayaUI_Chat", "XayaUI_Reskin") if not os.path.isdir(os.path.join(H.ROOT, m))]

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
local RV = QA and QA.Review
if RV and RV.Window and RV.Window() then RV.Window():Hide() end
ns.Print = function() end
local function C() local sv = ns.Service and ns.Service("chatDebug"); return sv and sv.C end
-- drive the runner as she would: Do it for me (when the step has one), then the addon's verdict (Accept) or Pass, or Done
local function Walk(id, plan)
  QA.Start(id)
  local def = QA.walks[id]
  local notes = {}
  for i, st in ipairs(def.steps) do
    if st.setup then QA.DoSetup(); W.tick(0.4, 3) end
    QA.RunCheck()
    local s = QA.State()
    notes[i] = s.seen and s.seen[i] and s.seen[i].d or ""
    local how = plan and plan[i] or (st.done and "D" or "accept")
    if how == "accept" and s.suggest then QA.Accept() elseif how == "accept" then QA.Answer("P") else QA.Answer(how) end
  end
  return QA.DB().results[id], notes
end
local function Check(id, i) local okC, v, n = pcall(QA.walks[id].steps[i].check); if not okC then return "ERR", tostring(v) end; return v, n end
'''

S1 = r'''
return function(W, L)
''' + COMMON + r'''
check("the reskin walkthrough is in three parts, the chat one too (Dev Assist 0.7.53)", QA.walks["reskin-switches-reload"] and QA.walks["reskin-switches-back"]
  and QA.walks["chat-improved-split-reload"] and QA.walks["chat-improved-split-back"])
if not QA.walks["reskin-switches-reload"] then return R end
local was = ns.ReskinTabOn()
check("(the reskins start switched on)", was == true)
-- the Esc Menu reskin on (its own box), so the look after each /reload has something to show or not
local RS = ns.Settings("reskin"); RS.gm = RS.gm or {}; RS.gm.skin = true   -- (P5: Blizzard Reskin's own store, XayaUIReskinDB.gm)
local res, notes = Walk("reskin-switches")
check("reskin part 1: the switch is flipped through Enable Blizzard Reskin itself: saved off, still on in effect until the /reload (0.6.79, PS-57), and the reload question asked",
  ns.ReskinTabSaved() == false and ns.ReskinTabOn() == true and C().skin == true and W.popup == "XAYAUI_RESKIN_RELOAD" and res and res.steps[2].r == "P" and tostring(res.steps[2].d):find("switch now OFF", 1, true), tostring(notes[2]))
check("reskin part 1: its last step is Done (no verdict) and tells her to /reload", res and res.steps[3].r == "D" and QA.walks["reskin-switches"].steps[3].text:find("/reload", 1, true) ~= nil)
local v, n = Check("reskin-switches-reload", 1)
check("reskin part 2 before any /reload: not tested (nil), says to reload", v == nil and tostring(n):find("not reloaded yet", 1, true) ~= nil, tostring(v) .. " " .. tostring(n))
-- chat part 1 (Chat Panel on, Improved Chat on to start)
local s = ns.chat2
s.enabled, s.improvedOn, s.barOn, s.collapsed = true, true, false, false
local skin0 = C().skin
local cres, cnotes = Walk("chat-improved-split", { [1] = "P" })
check("chat part 1: saves Chat Panel off / Improved Chat on, remembers yours in its result", s.enabled == false and s.improvedOn == true and cres
  and tostring(cres.steps[1].d):find("was: panel=1 improved=1 bar=0 collapsed=0", 1, true), tostring(cnotes[1]))
check("chat part 1: nothing applied before the /reload (the chat keeps its look)", C().skin == skin0, tostring(C().skin))
return R
end
'''

S2 = r'''
return function(W, L)
''' + COMMON + r'''
check("(after the /reload: the switch is off, as part 1 left it)", ns.ReskinTabOn() == false)
local v, n = Check("reskin-switches-reload", 1)
check("reskin part 2 after the /reload: the look follows the switch part 1 set (chat and Esc menu without the XayaUI look): Pass", v == true and tostring(n):find("part 1 set OFF", 1, true) ~= nil, tostring(v) .. " " .. tostring(n))
local Cc = C(); local real = Cc.skin
Cc.skin = true
local vb, nb = Check("reskin-switches-reload", 1)
check("reskin part 2 negative: the chat still drawn with the XayaUI art while the switch is off: Fail", vb == false and tostring(nb):find("chat should not have", 1, true) ~= nil, tostring(vb) .. " " .. tostring(nb))
Cc.skin = real
-- chat part 2 (Chat Panel off, Improved Chat on, after the /reload)
local cv, cn = Check("chat-improved-split-reload", 1)
check("chat part 2 after the /reload: Blizzard's chat (no XayaUI art), Improved Chat's pieces around it: Pass", cv == true, tostring(cv) .. " " .. tostring(cn))
local res = Walk("reskin-switches-reload")
check("reskin part 2: the switch is flipped back (saved on; still off in effect until the /reload) and the reload question asked", ns.ReskinTabSaved() == true and ns.ReskinTabOn() == false and res and res.steps[2].r == "P" and tostring(res.steps[2].d):find("switch now ON", 1, true), res and tostring(res.steps[2].d))
local cres = Walk("chat-improved-split-reload", { [2] = "P" })
check("chat part 2: saves Chat Panel on / Improved Chat off for the next /reload", ns.chat2.enabled == true and ns.chat2.improvedOn == false and cres and cres.steps[3].r == "D")
return R
end
'''

S3 = r'''
return function(W, L)
''' + COMMON + r'''
local v0, n0 = Check("reskin-switches-back", 1)
check("reskin part 3: until the Esc menu was opened once (its XayaUI panel is built on the first open), the look cannot be read: not tested (nil), says what to open",
  v0 == nil and tostring(n0):find("press Esc once", 1, true) ~= nil, tostring(v0) .. " " .. tostring(n0))
-- (the stand-in's game menu has no entries, so the Esc menu's XayaUI panel cannot be built here: a frame of that name stands for it)
if not rawget(_G, "XayaUI_GameMenuPanel") then CreateFrame("Frame", "XayaUI_GameMenuPanel", UIParent) end
local v, n = Check("reskin-switches-back", 1)
check("reskin part 3 after the second /reload: the switch is as it was before part 1 and the XayaUI look is back (chat, Esc menu); the character window left to her: Pass",
  v == true and tostring(n):find("switch ON", 1, true) ~= nil and tostring(n):find("Esc menu: XayaUI look present", 1, true) ~= nil
  and tostring(n):find("chat: XayaUI art present", 1, true) ~= nil and tostring(n):find("character window: yours to judge", 1, true) ~= nil, tostring(v) .. " " .. tostring(n))
local panel = rawget(_G, "XayaUI_GameMenuPanel"); _G.XayaUI_GameMenuPanel = nil
local vb, nb = Check("reskin-switches-back", 1)
_G.XayaUI_GameMenuPanel = panel
check("reskin part 3: with the Esc menu look on but never built (menu not opened), the check asks for Esc, no verdict", vb == nil and tostring(nb):find("press Esc once", 1, true) ~= nil, tostring(vb) .. " " .. tostring(nb))
GameMenuFrame:Show(); panel:Hide()
local vc, nc = Check("reskin-switches-back", 1)
GameMenuFrame:Hide(); panel:Show()
check("reskin part 3 negative: the Esc menu open without its XayaUI panel while the look is on: Fail", vc == false and tostring(nc):find("Esc menu should have", 1, true) ~= nil, tostring(vc) .. " " .. tostring(nc))
local cv, cn = Check("chat-improved-split-back", 1)
check("chat part 3 after the second /reload: the XayaUI art, none of Improved Chat's pieces: Pass", cv == true, tostring(cv) .. " " .. tostring(cn))
local res = Walk("chat-improved-split-back")
check("chat part 3: its last step (Done) saves your own switches back from part 1's record", ns.chat2.enabled == true and ns.chat2.improvedOn == true and ns.chat2.barOn == false and res and res.steps[2].r == "D")
return R
end
'''

S4 = r'''
return function(W, L)
''' + COMMON + r'''
check("after one more /reload: Chat Panel and Improved Chat as before part 1, and the chat drawn with the XayaUI art again", ns.chat2.enabled == true and ns.chat2.improvedOn == true and C().skin == true and ns.ReskinTabOn() == true)
return R
end
'''

# the same product actions without any walkthrough: the settings window opened on Blizzard Reskin, the switch off and on again,
# the character window and the Esc menu opened (what XayaUI itself saves for those is not the walkthroughs' doing)
PLAIN = r'''
return function(W, L)
''' + COMMON + r'''
if ns.OpenSettingsPage and ns.SetReskinTab then ns.OpenSettingsPage("reskin", "reskinOverview") end; W.tick(0.1, 3)
if ns.SetReskinTab then ns.SetReskinTab(false); ns.SetReskinTab(true) end; W.tick(0.1, 3)
if CharacterFrame then CharacterFrame:Show(); W.tick(0.1, 2); CharacterFrame:Hide() end
if GameMenuFrame then GameMenuFrame:Show(); W.tick(0.1, 2); GameMenuFrame:Hide() end
return R
end
'''


def session(src, saved):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": H.to_lua(L, saved)}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    results.append(("the saved files can be written by the game" + ("" if len(issues) == 0 else "  [%s]" % issues[1]), len(issues) == 0))
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs


def keypaths(v, path="", depth=0, maxd=99):
    out = set()
    if isinstance(v, dict) and depth < maxd:
        for k, x in v.items():
            out |= keypaths(x, path + "." + str(k), depth + 1, maxd)
    elif isinstance(v, list) and depth < maxd:
        out.add(path + "[]")
    else:
        out.add(path)
    return out


def main():
    bad, n, errs = 0, 0, []
    saved = {}
    if ABSENT:
        # the walkthroughs switch Blizzard Reskin and Improved Chat: nothing of them to walk without those modules. Each check is listed as skipped;
        # the plain session (settings window, character window, Esc menu) still runs and must load, run and save without a Lua error
        why = "QA-branch module absent: " + ", ".join(ABSENT)
        for i, src in enumerate((S1, S2, S3, S4), 1):
            for name in re.findall(r'check\("((?:[^"\\]|\\.)*)"', src):
                print("SKIP (%s) session %d: %s" % (why, i, name))
        for name in ("no new saved key in XayaUIDevAssistDB (only qa.results holds the runs)", "no new top-level saved key in CueRulesDB"):
            print("SKIP (%s) %s" % (why, name))
        results, plain, e = session(PLAIN, {})
        errs += e
        for name, ok in results[-1:]:
            n += 1
            print(("PASS " if ok else "FAIL ") + "plain session (modules absent): %s" % name)
            bad += 0 if ok else 1
        for e in errs:
            print("ERROR in the game stand-in:", str(e)[:600])
        print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
        sys.exit(1 if bad or errs else 0)
    for i, src in enumerate((S1, S2, S3, S4), 1):
        results, saved, e = session(src, saved if isinstance(saved, dict) else {})
        errs += e
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + "session %d: %s" % (i, name))
            if not ok:
                bad += 1
    _, plain, e = session(PLAIN, {})
    errs += e
    def sv(x, addon, var): return ((x or {}).get(addon) or {}).get(var) or {}
    da, dp = sv(saved, "XayaUI_DevAssist", "XayaUIDevAssistDB"), sv(plain, "XayaUI_DevAssist", "XayaUIDevAssistDB")
    extraTop = sorted(set(da.keys()) - set(dp.keys()) - {"qa"})
    qaKeys = sorted((da.get("qa") or {}).keys())
    ok = len(extraTop) == 0 and qaKeys == ["results"]
    n += 1
    print(("PASS " if ok else "FAIL ") + "no new saved key in XayaUIDevAssistDB (only qa.results holds the runs)" + ("" if ok else "  [%s / %s / %s]" % (extraTop, qaKeys, str(da)[:300])))
    bad += 0 if ok else 1
    ca, cp = keypaths(sv(saved, "XayaUI", "CueRulesDB"), maxd=1), keypaths(sv(plain, "XayaUI", "CueRulesDB"), maxd=1)
    # (.auraModel: the combat tracker makes its own store on its first settings read, XayaUI_Rules/Combat/AuraModel.lua DB(); whether a short
    # session reads it depends on what ran, not on the walkthroughs)
    extra = sorted(ca - cp - {".auraModel"})
    ok = len(extra) == 0
    n += 1
    print(("PASS " if ok else "FAIL ") + "no new top-level saved key in CueRulesDB" + ("" if ok else "  [%s]" % ", ".join(extra[:8])))
    bad += 0 if ok else 1
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
