#!/usr/bin/env python3
"""Xaya 2026-11-04 (screenshot of the ESC menu): "game menu when button is enabled clips incorrectly". The menu's box ended at the
bottom of Return to Game. A stand-in GameMenuFrame with geometry (tests/harness places frames from their anchors) lays itself out
from its pooled buttons only, like Blizzard's layout entries; another addon's button sits below them, placed by that addon, which
also made the menu taller. When GameMenu.lua adds its slot and calls Layout, that extra height was lost. Checks that after the
XayaUI button is added the menu still holds its lowest button with the bottom padding it had, never shrinks, and that nothing
changes with the XayaUI button switched off.
Run: python3 tests/gamemenu_fit_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the stand-in menu: buttons 30 px apart from 40 px below the top, 20 px padding under the last one (layout entries only)
local M = CreateFrame("Frame", "GameMenuFrame", UIParent)
M:SetSize(220, 100); M:SetPoint("TOP", UIParent, "TOP", 0, -100)
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
  M:SetHeight(-y + 20 - 2)   -- (the last step adds 30; the button is 28 tall: 20 px padding under it)
end
function M:InitButtons()
  for _, b in ipairs(pool.active) do b:Hide(); pool.free[#pool.free + 1] = b end
  pool.active = {}; nextIdx = 0
  for _, t in ipairs({ "Options", "Shop", "AddOns", "Support", MACROS or "Macros", "Log Out", "Exit Game", "Return to Game" }) do self:AddButton(t) end
  self:Layout()
end
MACROS = MACROS or "Macros"
-- another addon: after the menu is built it puts its own button under the last one and makes the menu 30 px taller for it
local other = CreateFrame("Button", "OtherAddonMenuButton", M); other:SetSize(200, 28)
hooksecurefunc(M, "InitButtons", function(self)
  local last = pool.active[#pool.active]
  other:ClearAllPoints(); other:SetPoint("TOP", last, "BOTTOM", 0, -2); other:Show()
  self:SetHeight(self:GetHeight() + 30)
end)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
check("core loaded with the Game Menu fit", ns and type(ns.GameMenuFitHeight) == "function")
local function gap() return other:GetBottom() - M:GetBottom() end
local function open() M:InitButtons(); W.tick(0.05, 2) end
-- with the XayaUI button switched off: the other addon's height stands (the reference)
CueRulesDB.ui = CueRulesDB.ui or {}
CueRulesDB.ui.hideGameMenuButton = true
open()
local h0, g0 = M:GetHeight(), gap()
check("button off: the other addon's button fits, 20 px under it", math.abs(g0 - 20) < 0.6, g0)
-- with the XayaUI button on
CueRulesDB.ui.hideGameMenuButton = nil
open()
local xb = _G.XayaUI_GameMenuButton
check("button on: the XayaUI slot is added", xb ~= nil and #pool.active == 9, #pool.active)
check("button on: the menu still holds the other addon's lowest button with the same 20 px under it (it was cut off)",
  math.abs(gap() - 20) < 0.6, gap())
check("button on: the menu is one row taller than with the button off (the XayaUI row), not shorter", M:GetHeight() >= h0 + 29.5, M:GetHeight() .. " vs " .. h0)
-- a menu that already fits is not touched
local before = M:GetHeight()
local fit = ns.GameMenuFitHeight
if fit then fit(M, 20) end
check("a menu that already fits keeps its height", fit ~= nil and M:GetHeight() == before)
other:Hide()
if fit then fit(M, 20) end
check("never made shorter (with the other button hidden the menu stays as it is)", fit ~= nil and M:GetHeight() == before)
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
