#!/usr/bin/env python3
"""The page info icon (core 0.6.59, Bonus 0.6.21; REQUEST-LOG UI-53, her answers to the tooltip redesign UI-51: section-wide text
"isolated to an info icon that opens/closes a description box -- try this out for one text-heavy segment and confirm POC before
proceeding for all"; tooltips "Up to two sentences", "Title + description"). The trial page: Bonus Features > Utilities > Calculator.
Checks, on the real addons in the stand-in game: the page shows a short summary (at most two sentences) and an info icon with no name
under it; the three long paragraphs are not shown; the icon's hover has a title line and one sentence; clicking it shows the three
paragraphs in a box (an inline group), clicking again hides them; the Open calculator button is still on the page and opens it.
Run: python3 tests/info_box_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa; slow)."""
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
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
local ACD = LibStub("AceConfigDialog-3.0")
pcall(ns.ToggleUI); W.tick(0.1, 4)
local function root() return ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function widgets(t)
  local out = {}
  local function walk(w, d) if not w or d > 20 then return end; if w.type == t then out[#out + 1] = w end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end end
  walk(root(), 0); return out
end
local function texts()
  local s = {}
  for _, w in ipairs(widgets("Label")) do if w.label and w.frame:IsShown() then s[#s + 1] = w.label:GetText() or "" end end
  return table.concat(s, " | ")
end
local function icon()
  for _, w in ipairs(widgets("Icon")) do
    local o = w:GetUserData("option"); if o and type(o.arg) == "table" and o.arg.xuiInfoToggle then return w, o end
  end
end
ACD:SelectGroup("CueRules", "bonus", "utilities", "calculator"); W.tick(0.3, 4)
local t = texts()
check("the page shows its summary", t:find("A small calculator: a window with a typed line and a keypad.", 1, true) ~= nil, t:sub(1, 200))
local sum = "A small calculator: a window with a typed line and a keypad. Open it with the button below or /calc."
local n = 0; for _ in sum:gmatch("[%.!?]%s") do n = n + 1 end; if sum:match("[%.!?]$") then n = n + 1 end
check("  ...the summary is at most two sentences (her answer)", n <= 2, n)
check("  ...the three long paragraphs are not shown (closed at first)", not t:find("It reads numbers", 1, true) and not t:find("A sum after the command", 1, true), t:sub(1, 300))
local ic, io = icon()
check("an info icon sits on the page", ic ~= nil)
check("  ...with no name under it", ic and not (ic.label and ic.label:IsShown()))
local d = io and (type(io.desc) == "function" and io.desc() or io.desc)
local dn = 0; for _ in tostring(d):gmatch("[%.!?]") do dn = dn + 1 end
check("  ...its hover: a title line and up to two sentences", io and io.name == "Description" and type(d) == "string" and dn >= 1 and dn <= 2, tostring(d))
if io then io.func() end; W.tick(0.3, 4)
ACD:SelectGroup("CueRules", "bonus", "utilities", "calculator"); W.tick(0.3, 4)
t = texts()
local inBox = false
for _, g in ipairs(widgets("InlineGroup")) do
  for _, c in ipairs(g.children or {}) do if c.type == "Label" and (c.label:GetText() or ""):find("It reads numbers", 1, true) then inBox = true end end
end
check("clicked: the three paragraphs show, in a box", t:find("It reads numbers", 1, true) and t:find("A sum after the command", 1, true) and inBox, tostring(t:find("It reads numbers", 1, true)) .. "/" .. tostring(t:find("A sum after the command", 1, true)) .. "/" .. tostring(inBox))
ic, io = icon(); if io then io.func() end; W.tick(0.3, 4)
ACD:SelectGroup("CueRules", "bonus", "utilities", "calculator"); W.tick(0.3, 4)
check("clicked again: closed", not texts():find("It reads numbers", 1, true))
local openB
for _, w in ipairs(widgets("Button")) do local o = w:GetUserData("option"); if o and o.name == "Open calculator" then openB = o end end
check("the Open calculator button is still on the page and opens it", openB ~= nil and (pcall(openB.func) and _G.XayaUICalculator ~= nil and _G.XayaUICalculator:IsShown()))
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
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
