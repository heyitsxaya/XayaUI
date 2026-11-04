#!/usr/bin/env python3
"""Xaya 2026-11-04 (screenshot: the Game Menu's dark panel runs far below Return to Game): "escape menu looks sus", then "closing and
reopening the esc menu made it even larger". Core 0.6.32's Game Menu fit measured the menu's bottom padding again on every open, from
the menu as it was already drawn (GameMenu.lua padBefore = BottomGap(menu)), and never made the menu shorter. When the menu's own
layout keeps its current height (a stand-in with a child that covers it), each open measured the last open's extra row as padding: the
menu grew by one row per open. Checks that the padding is the menu's natural one, measured once, and that the height is fitted to the
buttons (shorter as well as taller): stable over four opens, and a menu already too tall comes back.
Run: python3 tests/gamemenu_ratchet_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the stand-in menu: buttons 30 px apart from 40 px below the top, 20 px under the last one. Its Layout fits the buttons, but, like a
-- layout frame with a child that covers it (a skin's backdrop sized to the menu), it never makes itself shorter than it is now
-- (INFERENCE about why Xaya's menu grew on every open: "closing and reopening the esc menu made it even larger", 2026-11-04)
local M = CreateFrame("Frame", "GameMenuFrame", UIParent)
M:SetSize(220, 100); M:SetPoint("TOP", UIParent, "TOP", 0, -100)
local cover = CreateFrame("Frame", nil, M); cover:SetAllPoints(M)   -- the child that covers the menu
local pool = { active = {}, free = {} }
function pool:EnumerateActive() local i, t = 0, self.active; return function() i = i + 1; return t[i] end end
M.buttonPool = pool
local nextIdx = 0
function M:AddButton(text, cb)
  local b = table.remove(pool.free) or CreateFrame("Button", nil, M)
  b:SetSize(200, 28); b:SetText(text); b:Show(); nextIdx = nextIdx + 1; b.layoutIndex = nextIdx
  pool.active[#pool.active + 1] = b
  return b
end
function M:Layout()
  table.sort(pool.active, function(a, b) return a.layoutIndex < b.layoutIndex end)
  local y = -40
  for _, b in ipairs(pool.active) do b:ClearAllPoints(); b:SetPoint("TOP", M, "TOP", 0, y); y = y - 30 end
  M:SetHeight(math.max(-y + 20 - 2, M:GetHeight()))   -- never shorter than now: the covering child holds it
end
function M:InitButtons()
  for _, b in ipairs(pool.active) do b:Hide(); pool.free[#pool.free + 1] = b end
  pool.active = {}; nextIdx = 0
  for _, t in ipairs({ "Options", "Shop", "AddOns", "Support", MACROS or "Macros", "Log Out", "Exit Game", "Return to Game" }) do self:AddButton(t) end
  self:Layout()
end
MACROS = MACROS or "Macros"
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
check("core loaded", ns ~= nil)
local function lowest() local lo; for _, b in ipairs(pool.active) do if b:IsShown() then local bb = b:GetBottom(); if not lo or bb < lo then lo = bb end end end; return lo end
local function gap() return lowest() - M:GetBottom() end
local function open() M:InitButtons(); W.tick(0.05, 2) end
open()
local h1, g1 = M:GetHeight(), gap()
check("first open: the XayaUI row is added and 20 px stay under Return to Game", #pool.active == 9 and math.abs(g1 - 20) < 0.6, ("%d buttons, gap %.1f"):format(#pool.active, g1))
open(); open(); open()
check("opened four times: the menu keeps its height (it grew by a row each open)", math.abs(M:GetHeight() - h1) < 0.6, ("%.0f -> %.0f"):format(h1, M:GetHeight()))
check("  ...and still 20 px under Return to Game", math.abs(gap() - 20) < 0.6, gap())
-- a menu already too tall (as Xaya's was, before this fix) is brought back to its buttons
M:SetHeight(M:GetHeight() + 400); open()
check("a menu left far too tall is fitted back to its buttons on the next open", math.abs(M:GetHeight() - h1) < 0.6 and math.abs(gap() - 20) < 0.6, ("%.0f, gap %.1f"):format(M:GetHeight(), gap()))
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n not in ("XayaUI_DevAssist", "XayaUI_Reskin")]
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
