#!/usr/bin/env python3
"""Offline test (Options 0.6.3, #257): the open / close button that Skin.lua draws at the left of a collapsible header (arg.xuiChevron),
the header row no longer reacting to the mouse (no red mouse-over glow, not a click target), the duplicate icon, and everything being put
back when AceGUI reuses the widget. Uses a real AceGUI Button in the stand-in game. Run: python3 tests/header_chevron_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok) R[#R + 1] = { name, ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end
ns = rawget(_G, "XayaUI_NS")
check("skin loaded and on", ns and ns.DecorateTrees ~= nil and ns.SkinRows and ns.SkinRows())
local AceGUI = LibStub("AceGUI-3.0")
local root = AceGUI:Create("SimpleGroup")
local open, clicks = true, 0
local btn = AceGUI:Create("Button")
btn:SetUserData("option", { type = "execute", arg = { xuiLeft = true, xuiHeadOut = 20, xuiChevron = function() return open end,
  xuiActions = function() return { up = false, down = function() end, copy = function() end, del = function() end } end } })
btn:SetText("Trigger 1:  Buff / Aura")
btn:SetCallback("OnClick", function() clicks = clicks + 1; open = not open end)
root:AddChild(btn)
ns.DecorateTrees(root)
local f = btn.frame
local b = f.xuiChevBtn
check("an open / close button is drawn", b ~= nil and b:IsShown())
check("it shows the minus (open) art", b and tostring(b.tex:GetTexture()):find("UI%-MinusButton") ~= nil)
check("it sits inside the row at the left (not in the cut-off margin)", (function() local p = b and b._pts and b._pts[1]; return p and p[1] == "LEFT" and (p[4] or 0) >= 0 end)())
check("the title starts to the right of the button", f.xuiTitleX and f.xuiTitleX >= 22)
check("the header row does not react to the mouse", f._mouse == false)
check("no mouse-over glow on the header row", f:GetHighlightTexture():GetAlpha() == 0)
b:GetScript("OnClick")(b)
check("clicking the button opens / closes the section (the header's own action runs)", clicks == 1 and open == false)
ns.DecorateTrees(root)
check("closed: plus art", tostring(b.tex:GetTexture()):find("UI%-PlusButton") ~= nil)
local copy = f.xuiAct and f.xuiAct.copy
check("duplicate icon is drawn art (two squares), not the note texture", copy and copy.xuiCopyLines and #copy.xuiCopyLines == 8 and copy.tex:GetTexture() == nil)
-- a header without xuiChevron keeps behaving as before (clickable), only without the red glow
local plain = AceGUI:Create("Button")
plain:SetUserData("option", { type = "execute", arg = { xuiLeft = true } })
plain:SetText("Plain header")
root:AddChild(plain)
ns.DecorateTrees(root)
check("a header without the button stays clickable", plain.frame._mouse ~= false and not (plain.frame.xuiChevBtn and plain.frame.xuiChevBtn:IsShown()))
-- release: AceGUI reuses frames; the next user must get a normal button back
btn:Release()
check("released: button hidden, row takes the mouse again, glow restored", not b:IsShown() and f._mouse ~= false and f:GetHighlightTexture():GetAlpha() == 1 and f.xuiTitleX == nil)
local again = AceGUI:Create("Button")
check("reused widget is a normal button", again.frame._mouse ~= false and not (again.frame.xuiChevBtn and again.frame.xuiChevBtn:IsShown()))
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = ["XayaUI", "XayaUI_Media", "XayaUI_Options"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), H.to_lua(L, {}))
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
