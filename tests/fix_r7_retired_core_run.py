#!/usr/bin/env python3
"""Round 7 (bundle 1), core code that served only the retired QA-branch addons is removed (V34 audit, its section "Core code that serves
only retired QA-branch addons"; REQUEST-LOG A23 SD-58: "Core code serving only retired QA addons ... removal proposed"; V30: main holds
XayaUI, XayaUI_Options and XayaUI_Rules, every other addon lives on qa-installer-branch with its own copy of core).

Only the parts with no caller in XayaUI, XayaUI_Options or XayaUI_Rules and no effect on saved data or profile strings were removed
(the round-7 core report lists the rest, with why each stays). Players' saved settings of the retired addons are never deleted: only
code goes. What the player gets, checked with the real addons in the stand-in game ([new] = fails on the pre-change files, proved on a
copy of HEAD 2381c09d):
  Q  [new] /xui dev qa, /xui qa and /xui qatest no longer tell her to switch on XayaUI Dev Assist (not on main, so there is nothing to
     switch on): each prints the command list, as any word core does not know does.
  O  [new] another addon's Lua error leaves nothing in XayaUI (the count kept for Dev Assist's walkthrough J22 is gone); the error still
     reaches the error handler that was set before XayaUI (Core.lua chains it).
  E  [new] Advanced Debugging on: the record listens to the two "action blocked" events and nothing a retired addon hands in
     (DebugRecord.lua's DR.extraEvents / DR.extraHandlers hand-in is gone), and Settings > Debugging's change calls no Dev Assist hook
     (DevRecordChanged).
  R  [new] the debug report has no reader for imported report strings any more (ns.DebugReportRead: only Dev Assist used it); the report
     itself still opens (XayaUI_Debug, with Advanced Debugging on).
  S  Saved settings of retired addons stay as they were: a saved CueRulesDB.chat, .qol and .rsk survive a login, a play and a logout.
Run: python3 tests/fix_r7_retired_core_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
local W, L = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function since(n) local t = {}; for i = n + 1, #W.printed do t[#t + 1] = plain(W.printed[i]) end; return t end
local function count(lines, text) local n = 0; for _, l in ipairs(lines) do if l:find(text, 1, true) then n = n + 1 end end; return n end
-- (O: the handler set before XayaUI loads must still get every error)
local prev = {}
local gameHandler = geterrorhandler()
seterrorhandler(function(msg) prev[#prev + 1] = tostring(msg); return gameHandler(msg) end)
L.startup()
local ns = rawget(_G, "XayaUI_NS")
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
CueRulesDB.ui.msgDest = "chat"

-- Q
for _, cmd in ipairs({ "dev qa", "qa", "qatest" }) do
  local n = #W.printed
  SlashCmdList.XAYAUI(cmd)
  local got = since(n)
  check("[new] Q /xui " .. cmd .. ": no line about XayaUI Dev Assist; the command list instead",
    count(got, "Dev Assist") == 0 and #got >= 2 and got[1]:find("^XayaUI: commands %(%d+%):") ~= nil, table.concat(got, " / "):sub(1, 200))
end

-- O
local errs0 = #W.errors
local n = #prev
for _ = 1, 5 do pcall(geterrorhandler(), "Interface/AddOns/OtherAddon/Main.lua:12: attempt to index a nil value") end
check("[new] O another addon's errors (5) leave nothing in XayaUI: no count of them is kept", ns.otherErrors == nil, ns.otherErrors)
check("O ... and every one still reaches the error handler set before XayaUI, unchanged", #prev == n + 5
  and prev[#prev] == "Interface/AddOns/OtherAddon/Main.lua:12: attempt to index a nil value", #prev - n)
check("O ... and XayaUI records none of them", #(CueRulesDB.errorLog or {}) == 0, #(CueRulesDB.errorLog or {}))

-- E
local DR = ns.DebugRecordInfo
local devHook = 0
ns.SetDebugHooks({ DevRecordChanged = function() devHook = devHook + 1 end })
DR.extraEvents = function() return { UNIT_AURA = true, PLAYER_TARGET_CHANGED = true } end
DR.extraHandlers = { UNIT_AURA = function() end }
CueRulesDB.ui.advancedDebug = true; ns.DebugSettingsChanged()
local ev, list = DR.EventsOn(), {}
for e in pairs(ev) do list[#list + 1] = e end
table.sort(list)
check("[new] E Advanced Debugging on: the record listens to the two 'action blocked' events only, nothing a retired addon hands in",
  #list == 2 and ev.ADDON_ACTION_BLOCKED and ev.ADDON_ACTION_FORBIDDEN, table.concat(list, ","))
check("[new] E ... and Settings > Debugging's change calls no Dev Assist hook", devHook == 0 and ns.DevRecordChanged == nil, devHook)
CueRulesDB.ui.advancedDebug = nil; ns.DebugSettingsChanged()
DR.extraEvents, DR.extraHandlers = nil, nil

-- R
check("[new] R the debug report has no reader for imported report strings (only XayaUI Dev Assist used it)", ns.DebugReportRead == nil)

-- S
check("S the retired addons' saved settings are untouched after the login and a play", type(CueRulesDB.chat) == "table" and CueRulesDB.chat.keep == "chat"
  and type(CueRulesDB.qol) == "table" and CueRulesDB.qol.keep == "qol" and CueRulesDB.ui.rsk and CueRulesDB.ui.rsk.keep == "reskin")
check("(sanity) no Lua error from XayaUI", #W.errors == errs0 + 5, #W.errors - errs0)
local out = L.logout()
local db = out.XayaUI and out.XayaUI.CueRulesDB or {}
check("S ... and saved again at the logout", type(db.chat) == "table" and db.chat.keep == "chat" and type(db.qol) == "table" and db.qol.keep == "qol"
  and type(db.ui) == "table" and type(db.ui.rsk) == "table" and db.ui.rsk.keep == "reskin")
return R
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    saved = {"XayaUI": {"CueRulesDB": {"version": 1, "chat": {"keep": "chat"}, "qol": {"keep": "qol"},
                                      "ui": {"rsk": {"keep": "reskin"}}}}}
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    errs = [e for e in errs if "OtherAddon/Main.lua" not in e]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for x in errs:
        print("ERROR in the game stand-in:", x[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
