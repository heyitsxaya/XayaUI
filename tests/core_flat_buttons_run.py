#!/usr/bin/env python3
"""UI-77 (O-139, core 0.6.68): core's own windows have the flat button look after a /reload, without the settings addon.
Xaya: "reloading with console open failed to reskin buttons". The look came from the "buttonSkin" service, which only the settings
addon (LoadOnDemand) provided, so a console reopened at login kept Blizzard's red buttons until the settings window was opened.
Now the look is core's own (Core.lua ns.PaintFlatButton). This test starts the game with the console saved as open, never loads
the settings addon, and checks every text button of the console, the copy box and the debug report. The close X keeps Blizzard's
look on purpose (as the settings window's and the version pane's do; flagged to Xaya in the request log, UI-77).
Run: python3 tests/core_flat_buttons_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
check("the settings addon is not loaded (as after a /reload)", ns and ns.BuildOptionsTable == nil and not L.loaded["XayaUI_Options"])
local function buttons(frame)
  local out = {}
  for _, k in ipairs({ frame:GetChildren() }) do
    if k.GetObjectType and k:GetObjectType() == "Button" and k.GetText and k:GetText() then out[k:GetText()] = k end
  end
  return out
end
local function flat(b, label)
  if not b then return false, label .. ": button missing" end
  if not b.xuiFlatBtn then return false, label .. ": no flat look" end
  if not (b.xuiFlat and b.xuiFlat.bg and b.xuiFlat.bg:IsShown()) then return false, label .. ": no flat box" end
  local ht = b:GetHighlightTexture(); if ht and ht:GetAlpha() ~= 0 then return false, label .. ": Blizzard highlight shown" end
  local want = ns.Theme.Col("xui-button", "text", { 1, 0.82, 0, 1 })   -- the theme's button text (gold in the default theme)
  local r, g, bl = b:GetFontString():GetTextColor()
  if not (math.abs(r - want[1]) < 0.01 and math.abs(g - want[2]) < 0.01 and math.abs(bl - want[3]) < 0.01) then
    return false, label .. (": text %.2f,%.2f,%.2f, theme's button text %.2f,%.2f,%.2f"):format(r, g, bl, want[1], want[2], want[3]) end
  return true
end
-- 1) the console, reopened at login because it was open before the reload
local win = rawget(_G, "XayaUIConsoleWindow")
check("the console reopened at login", win ~= nil and win:IsShown())
if win then
  local bs = buttons(win)
  for _, lbl in ipairs({ "What to send", "Copy", "Clear", "Bug report" }) do
    local ok, why = flat(bs[lbl], lbl)
    check("console: " .. lbl .. " has the flat look", ok, why)
  end
  -- hidden and shown again: still flat (the OnShow repaint). The game fires a child's OnShow when its window shows; the stand-in
  -- fires only the frame's own, so the button itself is hidden and shown here.
  bs["Copy"]:Hide(); bs["Copy"]:Show()
  local ok, why = flat(bs["Copy"], "Copy")
  check("console: still flat after it is hidden and shown again", ok, why)
end
-- 2) the copy box (What to send)
pcall(ns.ShowCopyBox, "XayaUI: test", "text"); W.tick(0.05, 2)
local cb = rawget(_G, "XayaUICopyBox")
check("the copy box opened", cb ~= nil and cb:IsShown())
if cb then local ok, why = flat(buttons(cb)["Select all"], "Select all"); check("copy box: Select all has the flat look", ok, why) end
-- 3) the debug report
pcall(ns.ShowDebugReport); W.tick(0.05, 2)
local dr = rawget(_G, "XayaUIDebugReport")
check("the debug report opened", dr ~= nil and dr:IsShown())
if dr then
  local bs, found = buttons(dr), nil
  for lbl, b in pairs(bs) do if lbl:find("string") then found = b end end
  local ok, why = flat(found, "the string button")
  check("debug report: the string button has the flat look", ok, why)
end
-- 4) skin off (/xuiskin): Blizzard's look comes back on the next show; skin on again: flat again
if win then
  local b = buttons(win)["Copy"]
  CueRulesDB.ui.skinOff = true; b:Hide(); b:Show()
  check("skin off: Blizzard's look is back", b and b.xuiFlat and not b.xuiFlat.bg:IsShown() and b:GetHighlightTexture():GetAlpha() == 1)
  CueRulesDB.ui.skinOff = nil; b:Hide(); b:Show()
  local ok, why = flat(b, "Copy"); check("skin on again: flat again", ok, why)
end
-- 5) a theme change repaints the shown buttons at once (the console reopened at login is built before the theme is applied)
if win then
  local b = buttons(win)["Clear"]
  CueRulesDB.theme = CueRulesDB.theme or {}
  CueRulesDB.theme.tokens = CueRulesDB.theme.tokens or {}
  CueRulesDB.theme.tokens.buttonText = { 0.2, 0.9, 0.3, 1 }
  ns.Theme.Resolve()
  local r, g, bl = b:GetFontString():GetTextColor()
  check("a theme change repaints the console's buttons at once", math.abs(g - 0.9) < 0.01 and math.abs(r - 0.2) < 0.01, ("%.2f,%.2f,%.2f"):format(r, g, bl))
  CueRulesDB.theme.tokens.buttonText = nil; ns.Theme.Resolve()
end
-- 6) one copy of the look: the settings addon's ns.SkinPlainButton calls core's
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
if ns.SkinPlainButton then
  local seen
  local real = ns.PaintFlatButton
  ns.PaintFlatButton = function(b, p) seen = { b, p }; return real(b, p) end
  local t = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate"); t:SetText("x")
  ns.SkinPlainButton(t, true)
  ns.PaintFlatButton = real
  check("the settings addon's flat button is core's look (one copy)", seen and seen[1] == t and seen[2] == true and t.xuiFlatBtn == true)
else
  check("the settings addon loads and keeps ns.SkinPlainButton", false, "missing")
end
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    saved = {"XayaUI": {"CueRulesDB": {"ui": {"consoleOpen": True}}}}
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
