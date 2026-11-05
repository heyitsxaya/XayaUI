#!/usr/bin/env python3
"""The settings window's bottom strip and the Acknowledgements page (Options 0.6.30; Xaya 2026-11-04): AceGUI's empty status bar left of Close is hidden while
XayaUI uses the window ("bottom random bar left of close should be removed") and shown again when the window is handed back to
AceGUI; the version is in the bottom-left corner ("addon version should be put in the bottom left"); since Options 0.6.39 the version
text itself is the Addon Info link, in the theme's accent colors. Uses a real AceGUI Frame widget registered as the open settings window (the settings tree itself is not drawn), and the window
driver that dresses it every 0.25 s.
Run: python3 tests/window_footer_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)
VER = re.search(r"^## Version:\s*(\S+)", open(os.path.join(HERE, "..", "XayaUI", "XayaUI.toc"), encoding="utf-8").read(), re.M).group(1)

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
-- Acknowledgements on their own page under Settings (Xaya 2026-11-04: "acknowledgements still needs to be put into settings into its
-- own tab"); Addon Info points there
local built = ns.BuildOptionsTable()
local ack = built.args.set and built.args.set.args.credits
local function has(t, key) return type(t) == "table" and type(t.args) == "table" and (t.args[key] ~= nil or (t.args.page and t.args.page.args and t.args.page.args[key] ~= nil)) end
check("Settings has an Acknowledgements page with the credits", ack ~= nil and ack.name == "Acknowledgements" and has(ack, "creditsH1") and has(ack, "sec1"))
check("the old single Settings tab (skin off) has it too", built.args.settings and built.args.settings.args.credits ~= nil)
local info = built.args.info
check("Addon Info no longer holds the credits, and says where they are",
  info and not has(info, "creditsH1") and not has(info, "sec1") and has(info, "creditsWhere")
  and tostring(info.args.page.args.creditsWhere.name):find("Settings > Acknowledgements", 1, true) ~= nil)
local AceGUI, ACD = LibStub("AceGUI-3.0"), LibStub("AceConfigDialog-3.0")
local of = AceGUI:Create("Frame")
local sb = of.statustext and of.statustext:GetParent()
check("AceGUI's Frame has its status bar (the text's parent), shown by default", sb ~= nil and sb:IsShown())
ACD.OpenFrames = ACD.OpenFrames or {}
ACD.OpenFrames["CueRules"] = of
of.frame:Show()
-- fed through AceConfigDialog:Open, as the game opens the window: its hook starts the window driver (Options 0.6.41: the driver runs
-- only while the window is open, started by that hook; before, it ran on every frame and found a frame registered by hand like this)
ACD:Open("CueRules", of)
W.tick(0.3, 3)
local c = of.xuiChrome
check("the window is dressed by XayaUI", c ~= nil)
if not c then return R end
check("the empty status bar left of Close is hidden", not sb:IsShown())
check("the version is in the bottom-left corner", c.ver and c.ver:IsShown() and c.ver:GetText() == "XayaUI v__VER__", c.ver and c.ver:GetText())
-- Options 0.6.39 (Xaya 2026-11-05): "remove Addon Info button, make the XayaUI version text clickable instead", "colorize it to active
-- theme colors"
local link = c.info
local p, rel, rp = link:GetPoint(1)
check("the version link is anchored to the window's bottom-left corner", p == "BOTTOMLEFT" and rel == of.frame and rp == "BOTTOMLEFT", tostring(p) .. " " .. tostring(rp))
check("the version text is the link's own text (one control, not a label beside a link)", link.text == c.ver and c.ver:GetParent() == link)
local function texts(f, out)
  out = out or {}
  for _, r in ipairs({ f:GetRegions() }) do if r.GetText then out[#out + 1] = tostring(r:GetText()) end end
  for _, k in ipairs({ f:GetChildren() }) do texts(k, out) end
  return out
end
local addonInfoText = false
for _, t in ipairs(texts(of.frame)) do if t == "Addon Info" then addonInfoText = true end end
check("no separate \"Addon Info\" text in the window's corner any more", not addonInfoText)
check("the click area covers the version text", link:GetWidth() >= c.ver:GetStringWidth(), link:GetWidth() .. " vs " .. c.ver:GetStringWidth())
local T = ns.Theme
local function same(a, b) return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01 end
local function col(fs) local r, g, b = fs:GetTextColor(); return { r, g, b } end
check("the version text is in the theme's accent color", same(col(c.ver), T.cur.accent), table.concat(col(c.ver), ","))
link:GetScript("OnEnter")(link)
check("hovered: the theme's lighter accent (selected row text)", same(col(c.ver), T.cur.accentText), table.concat(col(c.ver), ","))
link:GetScript("OnLeave")(link)
check("left: back to the accent", same(col(c.ver), T.cur.accent))
CueRulesDB.theme.tokens.accent = { 0.10, 0.90, 0.20, 1 }
T.Resolve()
check("a theme change repaints it", same(col(c.ver), { 0.10, 0.90, 0.20 }), table.concat(col(c.ver), ","))
CueRulesDB.theme.tokens.accent = nil; T.Resolve()
ns.infoOpen = false
local picked
local realSelect = ACD.SelectGroup
ACD.SelectGroup = function(self, app, ...) picked = table.concat({ ... }, ">"); return true end
link:Click()
ACD.SelectGroup = realSelect
check("clicking the version opens Addon Info", ns.infoOpen == true and picked == "info", tostring(picked))
ns.infoOpen = false
sb:Show(); W.tick(0.3, 1)
check("if anything shows the bar again while XayaUI has the window, it is hidden again", not sb:IsShown())
ACD.OpenFrames["CueRules"] = nil
AceGUI:Release(of)
check("released to AceGUI: the status bar is back for the next addon that gets this window", sb:IsShown())
check("...and the version link is gone with the rest of XayaUI's chrome", c.ver ~= nil and not c.ver:IsShown() and not c.info:IsShown())
return R
end
'''.replace("__VER__", VER)


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
