#!/usr/bin/env python3
"""The in-game QA walkthroughs for overlap flags and switches on reload (XayaUI_DevAssist 0.7.60, QAWalks-conflicts-reload.lua, QA I2;
PS-56 #469, PS-57 #480; standing rule V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report
fixes have an in game qa test walk through with pre-fill confirmation options or data capturing").
On the real addons (every one on) in the stand-in game, with every /reload a real one (the stand-in logs out, writes the saved files,
and a new session loads from them):
  - "conflicts" with ElvUI and Plater standing in as loaded: step 1 lists what was found at login and the login line and offers Pass
    (it matches a fresh read of the AddOns list); with the found list tampered (an addon dropped) it offers Fail; step 2 opens a flagged
    page and offers Pass when every flagged page has its line; with nothing loaded both steps offer Pass ("none").
  - "switch-reload" part 1 flips Blizzard Reskin > Chat Bubbles and QoL > Nameplates through their tick boxes: each asks for the reload
    and changes nothing before it (Pass); part 2's check before the /reload says "not reloaded yet" (no verdict); after the /reload
    part 2 sees both changes in effect (Pass) and flips both back; after the second /reload part 3 finds them as before part 1 (Pass).
  - no saved key of their own (only qa.results holds the runs).
Negative control: on Dev Assist 0.7.59 the walkthroughs do not exist (the registration check fails).
Run: python3 tests/qa_walk_conflicts_reload_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local LOADED_EXTRA = {}
for _, n in ipairs(EXTRA or {}) do LOADED_EXTRA[n] = true end
local rawLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(n) if LOADED_EXTRA[n] then return true, true end return rawLoaded(n) end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
local RV = QA and QA.Review
if RV and RV.Window and RV.Window() then RV.Window():Hide() end
ns.Print = function() end
local function Walk(id, plan)
  QA.Start(id)
  local def = QA.walks[id]
  local notes, sugg = {}, {}
  for i, st in ipairs(def.steps) do
    if st.setup then QA.DoSetup(); W.tick(0.4, 3) end
    QA.RunCheck()
    local s = QA.State()
    notes[i] = s.seen and s.seen[i] and s.seen[i].d or ""
    sugg[i] = s.suggest
    local how = plan and plan[i] or (st.done and "D" or "accept")
    if how == "accept" and s.suggest then QA.Accept() elseif how == "accept" then QA.Answer("P") else QA.Answer(how) end
  end
  return QA.DB().results[id], notes, sugg
end
local function Check(id, i) local okC, v, n = pcall(QA.walks[id].steps[i].check); if not okC then return "ERR", tostring(v) end; return v, n end
local NP = ns.Service("nameplates")
local function bubbles() return ns.Service("blizzardSkins").Live().bubbles and true or false end
local function listening() return NP.TargetColor.Listening() and true or false end
'''

S1 = r'''
return function(W, L, EXTRA)
''' + COMMON + r'''
check("the walkthroughs are registered with pre-fill (conflicts; switch-reload in three parts)", QA.walks["conflicts"] and QA.walks["conflicts"].prefill
  and QA.walks["switch-reload"] and QA.walks["switch-reload-after"] and QA.walks["switch-reload-back"] and QA.walks["switch-reload"].prefill)
if not QA.walks["conflicts"] then return R end
-- conflicts
local v1, n1 = Check("conflicts", 1)
check("conflicts step 1: what was found at login matches a fresh read of the AddOns list (Pass), and the note captures it",
  v1 == true and tostring(n1):find("ElvUI", 1, true) and tostring(n1):find("nameplates:Plater", 1, true) and tostring(n1):find("login line: overlaps with other loaded addons", 1, true), tostring(n1))
local rawFor = ns.ConflictsFor
ns.ConflictsFor = function(p) local l = rawFor(p); if p == "nameplates" and l then local out = {}; for _, e in ipairs(l) do if e.addon ~= "Plater" then out[#out + 1] = e end end; return out end return l end
local vn = Check("conflicts", 1)
ns.ConflictsFor = rawFor
check("conflicts step 1 negative: a loaded addon missing from what was found: Fail", vn == false, tostring(vn))
local res, notes = Walk("conflicts")
check("conflicts step 2: the first flagged page opens and every flagged page has its line (Pass)", res and res.steps[2].r == "P" and tostring(notes[2]):find("pages with their line:", 1, true)
  and not tostring(notes[2]):find("MISSING", 1, true), tostring(notes[2]))
-- switch-reload part 1
local b0, l0 = bubbles(), listening()
check("(start) Chat Bubbles not drawn, the nameplate colour listening", b0 == false and l0 == true)
local r1, nt1 = Walk("switch-reload")
check("switch-reload part 1: Chat Bubbles flipped, asked, nothing drawn before the reload (Pass)", r1 and r1.steps[1].r == "P" and tostring(nt1[1]):find("saved now ON (was OFF)", 1, true)
  and bubbles() == false, tostring(nt1[1]))
check("switch-reload part 1: Nameplates flipped, asked, still listening before the reload (Pass)", r1 and r1.steps[2].r == "P" and tostring(nt1[2]):find("saved now OFF (was ON)", 1, true)
  and listening() == true, tostring(nt1[2]))
local vb = Check("switch-reload-after", 1)
check("switch-reload part 2 before the /reload: no verdict (not reloaded yet)", vb == nil, tostring(vb))
return R
end
'''

S2 = r'''
return function(W, L, EXTRA)
''' + COMMON + r'''
local v, n = Check("switch-reload-after", 1)
check("switch-reload part 2 after the /reload: Chat Bubbles drawn, the nameplate colour no longer listening (Pass)", v == true and bubbles() == true and listening() == false, tostring(n))
local r2, nt2 = Walk("switch-reload-after")
check("switch-reload part 2: both flipped back and asked; nothing changes before the reload (Pass)", r2 and r2.steps[2].r == "P" and bubbles() == true and listening() == false, tostring(nt2[2]))
return R
end
'''

S3 = r'''
return function(W, L, EXTRA)
''' + COMMON + r'''
local v, n = Check("switch-reload-back", 1)
check("switch-reload part 3 after the second /reload: both as before part 1 (Pass)", v == true and bubbles() == false and listening() == true, tostring(n))
-- nothing loaded that overlaps: conflicts offers Pass with "none"
return R
end
'''

S4 = r'''
return function(W, L, EXTRA)
''' + COMMON + r'''
local v1, n1 = Check("conflicts", 1)
local v2, n2 = Check("conflicts", 2)
check("conflicts with no overlapping addon loaded: step 1 Pass (found: none), step 2 Pass (no part flagged)", v1 == true and tostring(n1):find("found at login: none", 1, true)
  and v2 == true and tostring(n2):find("no part is flagged", 1, true), tostring(n1) .. " | " .. tostring(n2))
return R
end
'''


def session(src, saved, extra):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": H.to_lua(L, saved)}))
    res = L.eval("function(src, W, Ld, x) return loadstring(src)()(W, Ld, x) end")(src, world, loader, H.to_lua(L, extra))
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs


def main():
    bad = n = 0
    errs = []
    saved = {}
    for i, src in enumerate((S1, S2, S3), 1):
        results, saved, e = session(src, saved if isinstance(saved, dict) else {}, ["ElvUI", "Plater"])
        errs += e
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + "session %d: %s" % (i, name))
            if not ok:
                bad += 1
    da = ((saved or {}).get("XayaUI_DevAssist") or {}).get("XayaUIDevAssistDB") or {}
    qa_keys = sorted((da.get("qa") or {}).keys())
    n += 1
    ok = qa_keys == ["results"]
    print(("PASS " if ok else "FAIL ") + "no saved key of their own (only qa.results holds the runs)" + ("" if ok else "  [%s]" % qa_keys))
    bad += 0 if ok else 1
    results, _, e = session(S4, {}, [])
    errs += e
    for name, ok in results:
        n += 1
        print(("PASS " if ok else "FAIL ") + "session 4: %s" % name)
        if not ok:
            bad += 1
    n += 1
    if errs:
        bad += 1
        print("FAIL no Lua errors in the stand-in game  [%s]" % str(errs[0])[:400])
    else:
        print("PASS no Lua errors in the stand-in game")
    print("%d checks, %d failed" % (n, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
