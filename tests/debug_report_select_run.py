#!/usr/bin/env python3
"""UI-78 (O-128, core 0.6.69): the debug report's string button. Xaya: "copy string button doesn't copy". An addon cannot put text on
the clipboard (CopyToClipboard is protected: secure code only, warcraft.wiki.gg API_CopyToClipboard, read 2026-11-07), so the button
only ever selected the string. Now it is named for what it does ("Select string"), a press selects the whole string and the hint then
says which keys copy it (Ctrl+C, Cmd+C on Mac); a click inside the box selects it all again; reopening puts the first hint back.
Run: python3 tests/debug_report_select_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local win = ns.ShowDebugReport and ns.ShowDebugReport()
check("the debug report opens", win ~= nil and win:IsShown())
if not win then return R end
local btn = win.copy
check("the button is named for what it does: Select string", btn and btn:GetText() == "Select string", btn and btn:GetText())
local h0 = win.hint:GetText() or ""
check("the first hint names Select string and the keys", h0:find("Select string", 1, true) and h0:find("Ctrl+C", 1, true) and h0:find("Cmd+C", 1, true), h0)
local hl = 0
local real = win.str.HighlightText
win.str.HighlightText = function(self, ...) hl = hl + 1; return real(self, ...) end
btn:GetScript("OnClick")(btn, "LeftButton")
check("a press selects the string (focus + whole text highlighted)", win.str:HasFocus() and hl >= 1, hl)
local h1 = win.hint:GetText() or ""
check("then the hint says to press Ctrl+C (Cmd+C on Mac)", h1:find("now press Ctrl+C", 1, true) and h1:find("Cmd+C on Mac", 1, true), h1)
hl = 0
local up = win.str:GetScript("OnMouseUp")
if up then up(win.str, "LeftButton") end
check("a click inside the box selects the whole string again", up ~= nil and hl >= 1, hl)
win:Hide(); ns.ShowDebugReport()
check("reopened: the first hint is back", win.hint:GetText() == h0, win.hint:GetText())
local send = ns.SendText and ns.SendText() or ""
check("What to send names Select string and the keys", send:find("press Select string, then Ctrl+C", 1, true) ~= nil, send:sub(1, 300))
check("nothing anywhere still says Copy string", not (send:find("Copy string", 1, true) or h0:find("Copy string", 1, true)))
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    # (round 7, REQUEST-LOG A23 SD-58 / SD-61) the console window and the reports are XayaUI_Debug's, read only while Advanced Debugging is on (off for a new install): saved on here, as every install before round 7 has it
    saved = {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": True}}}}
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
