#!/usr/bin/env python3
"""Xaya 2026-11-08 (request log row 26, "visual cuts off"): a cue's "Stacks / Charges Count" section with "Show a count" ticked showed
"Count options" open with nothing under it, and the rest of the pane (Shield / Absorb Amount, Position, Color, Animation) was gone.
Cause: Editor.lua's "Count of" sorting read cntArgs.source, which ns.GateRest had moved into the pane (nil), so AceConfigDialog
raised a Lua error while feeding the pane and stopped drawing. Opens the real settings window in the stand-in game.
Run: python3 tests/count_options_pane_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, KIND)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { KIND .. " cue: " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
pcall(ns.LoadOptions); W.tick(0.1, 5); ns = rawget(_G, "XayaUI_NS")
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useBuff = true; P.buffID = 203819; P.buffState = "present"; ns.NormalizeRule(P)
ns.rules = { P }
local cue = ns.NewCueRule(P, KIND)
cue.visual.count.enabled = true
-- 1) the option table alone: "Count of" must list its choices after GateRest moved it into the pane
local built = ns.BuildOptionsTable()
local srcOpt
local seen = {}
local function scan(t) if type(t) ~= "table" or seen[t] or srcOpt then return end; seen[t] = true
  if t.type == "select" and t.name == "Count of" and type(t.sorting) == "function" then srcOpt = t return end
  for _, v in pairs(t) do scan(v) end end
scan(built)
local okS, sorted = pcall(srcOpt and srcOpt.sorting or error)
check("the Count of list sorts without a Lua error", srcOpt ~= nil and okS and type(sorted) == "table" and #sorted > 0, tostring(sorted))
-- 2) the open window: Stacks / Charges Count opened, Show a count ticked, Count options open by default
local ACD = LibStub("AceConfigDialog-3.0")
if not (ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6)
local okx, ctx = pcall(ns.ReadContext)
local path = { ns.ScopePath(P, okx and ctx or nil) }; path[#path + 1] = "cues"
pcall(ACD.SelectGroup, ACD, "CueRules", unpack(path)); W.tick(0.05, 6)
local root = ACD.OpenFrames.CueRules
local function label(w) local o = w.GetUserData and w:GetUserData("option"); local n = o and o.name; if type(n) == "function" then local ok, v = pcall(n, {}); n = ok and v or nil end; return n end
local function find(pred) local f; local function walk(w) if f or type(w) ~= "table" then return end; if pred(w) then f = w return end; for _, c in ipairs(w.children or {}) do walk(c) end end; walk(root); return f end
local function btn(text) return find(function(w) return w.type == "Button" and label(w) == text end) end
local e0 = #W.errors
local hdr = btn("Stacks / Charges Count")
check("the Stacks / Charges Count header is drawn", hdr ~= nil)
if not hdr then return R end
hdr:Fire("OnClick"); W.tick(0.05, 6); pcall(ns.DecorateTrees); W.tick(0.05, 3)
check("opening it raises no Lua error", #W.errors == e0, W.errors[e0 + 1] and tostring(W.errors[e0 + 1]):sub(1, 160))
local paneHdr = btn("Count options")
local body = paneHdr and paneHdr.parent and paneHdr.parent.children[2]
local kids = body and body.children or {}
check("Count options is open and holds its controls (Count of first, then the text style)", #kids >= 9 and label(kids[1]) == "Count of", #kids)
check("its box is as tall as its controls", body and body.frame:GetHeight() > 300, body and body.frame:GetHeight())
check("the sections after it are still drawn (Shield / Absorb Amount)", btn("Shield / Absorb Amount") ~= nil)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    bad = nerr = n = 0
    for kind in ("icon", "text"):
        L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
        api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
        world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
        loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
            os.path.join(H.HERE, "loader.lua"), world,
            H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
        res = L.eval("function(src, W, Ld, k) return loadstring(src)()(W, Ld, k) end")(LUA, world, loader, kind)
        for i in range(1, len(res) + 1):
            name, ok = res[i][1], res[i][2]
            n += 1
            print(("PASS " if ok else "FAIL ") + name)
            if not ok:
                bad += 1
        for i in range(1, len(world.errors) + 1):
            nerr += 1
            print("ERROR in the game stand-in:", str(world.errors[i])[:300])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, nerr))
    sys.exit(1 if bad or nerr else 0)


if __name__ == "__main__":
    main()
