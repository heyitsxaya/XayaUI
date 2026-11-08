#!/usr/bin/env python3
"""Debug batch W3 (Options 0.6.97, Rules Options 0.6.81): the settings window's chrome, in the real window (real AceGUI, AceConfigDialog
and the XayaUI addons in the stand-in game). Triage: docs/process/audits/debug-triage-2026-11-08.md rows #468, #471, #478, #483.
  #478 (Xaya 2026-11-07): collapsed, "? and the collapse button now sit just left of the 'XayaUI' title and X just right of it ...
       Expected: the same positions as when open, at the right edge": the X, the collapse arrow and the ? keep their places.
  #468: the window's own bottom Close button is red (stock); XayaUI's own windows always have the flat look, whatever Blizzard Reskin >
       Buttons says. Also the title bar's ? and collapse arrow. The Close button is AceGUI's again when AceGUI takes the window back.
  #471 items 1-3 (her "correct on all fronts"): the Theme string box's stock Accept button is flat; the class boxes' Reset buttons in
       one column inside their box; "Delete saved" inside the page's margin (ns.Style.margin).
  #483 (J31 step 3, "nothing happens on click"; step text "the rule's tab with that option opens"): the result's tab opens, the
       results fold away (the typed text stays) and the option is scrolled into the visible part of the page.
Each check fails on a930f74 (the code before W3); see debug-log/2026-11-08-*-debug-w3-*.md.
Run: python3 tests/debug_w3_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
-- a rule with an icon cue, for the rule search (#483)
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useCd = true; P.spellID = 203720; P.cdState = "ready"; ns.NormalizeRule(P)
ns.rules[#ns.rules + 1] = P
ns.NewCueRule(P, "icon")
pcall(ns.MarkDirty)
local ACD = LibStub("AceConfigDialog-3.0")
if not (ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6)
local of = ACD.OpenFrames and ACD.OpenFrames.CueRules
check("the settings window is open", of ~= nil)
if not of then return R end
local c = of.xuiChrome
check("the window is dressed by XayaUI (title-bar buttons made)", c and c.close and c.arrow and c.help)
if not (c and c.close and c.arrow and c.help) then return R end

-------------------------------------------------------------------------------- #478
local function pos(b) return { b:GetRight(), b:GetTop() } end
local function same(a, b) return math.abs(a[1] - b[1]) < 0.5 and math.abs(a[2] - b[2]) < 0.5 end
local function fmt(a) return ("%.1f,%.1f"):format(a[1], a[2]) end
local open = { x = pos(c.close), a = pos(c.arrow), h = pos(c.help) }
local fr = of.frame
check("#478 open: the X sits at the window's top-right edge", math.abs(open.x[1] - (fr:GetRight() - 6)) < 0.5, fmt(open.x) .. " frame right " .. fr:GetRight())
c.arrow:GetScript("OnClick")(c.arrow); W.tick(0.05, 4)
check("(the window is collapsed)", c.collapsed == true)
check("#478 collapsed: the X stays where it is when open (right edge)", same(pos(c.close), open.x), fmt(pos(c.close)) .. " vs " .. fmt(open.x))
check("#478 collapsed: the collapse arrow stays where it is when open", same(pos(c.arrow), open.a), fmt(pos(c.arrow)) .. " vs " .. fmt(open.a))
check("#478 collapsed: the ? stays where it is when open", same(pos(c.help), open.h), fmt(pos(c.help)) .. " vs " .. fmt(open.h))
check("#478 collapsed: all three still shown", c.close:IsShown() and c.arrow:IsShown() and c.help:IsShown())
-- a redraw while collapsed (a rule changed, a walkthrough step): the window keeps its width, so the buttons keep their places
pcall(LibStub("AceConfigRegistry-3.0").NotifyChange, LibStub("AceConfigRegistry-3.0"), "CueRules"); W.tick(0.05, 6)
check("#478 collapsed, after a redraw: the X, the arrow and the ? are still where they are when open",
  same(pos(c.close), open.x) and same(pos(c.arrow), open.a) and same(pos(c.help), open.h), fmt(pos(c.close)) .. " vs " .. fmt(open.x))
local tleft, tright = of.titletext:GetLeft(), of.titletext:GetRight()
check("#478 collapsed: none of them next to the \"XayaUI\" title (the X is not just right of it, the arrow not just left of it)",
  c.close:GetLeft() > tright + 100 and c.arrow:GetLeft() > tright + 100, ("X left %.0f, arrow left %.0f, title %.0f-%.0f"):format(c.close:GetLeft(), c.arrow:GetLeft(), tleft, tright))
c.arrow:GetScript("OnClick")(c.arrow); W.tick(0.05, 4)
check("#478 expanded again: the same places", c.collapsed == false and same(pos(c.close), open.x) and same(pos(c.arrow), open.a) and same(pos(c.help), open.h))

-------------------------------------------------------------------------------- #468
local T = ns.Theme
local function near(a, b) return a and b and math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01 end
-- flat = Blizzard's red art (the template's Left / Middle / Right) faded out, and XayaUI's box drawn in the theme's button colours
local function Flat(b)
  if not b then return false, "no button" end
  for _, k in ipairs({ "Left", "Middle", "Right" }) do
    local t = b[k]
    if t and t:GetAlpha() > 0.01 then return false, k .. " art alpha " .. t:GetAlpha() end
  end
  local box = b.xuiFlat
  if not (box and box.bg and box.bg:IsShown()) then return false, "no flat box" end
  local want = T.Col("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 })
  if not near(box.bg._color, want) then return false, "box colour " .. table.concat(box.bg._color or {}, ",") end
  return true, "flat"
end
local function Stock(b)
  for _, k in ipairs({ "Left", "Middle", "Right" }) do if b[k] and b[k]:GetAlpha() < 0.99 then return false end end
  return not (b.xuiFlat and b.xuiFlat.bg and b.xuiFlat.bg:IsShown())
end
local closeBtn
local sb = of.statustext and of.statustext:GetParent()
for _, ch in ipairs({ fr:GetChildren() }) do
  if ch ~= sb and ch.obj == of and ch:GetObjectType() == "Button" and ch.GetText and ch:GetText() == CLOSE then closeBtn = ch end
end
check("(found the window's bottom Close button: AceGUI Frame's own)", closeBtn ~= nil)
local cr = ns.Settings("reskin")
check("(Blizzard Reskin > Buttons is not on: the Close button gets no flat look from it)", not (cr and cr.blizzard and cr.blizzard.buttons == true))
local okF, whyF = Flat(closeBtn)
check("#468 the bottom Close button has XayaUI's flat look (red art hidden, theme button box)", okF, whyF)
check("#468 it still closes the window (its click is AceGUI's)", closeBtn and closeBtn:GetScript("OnClick") ~= nil)
local okA, whyA = Flat(c.arrow); check("#468 the title bar's collapse arrow is flat", okA, whyA)
check("#468 ...and its arrow glyph stays visible", c.arrow.tex and c.arrow.tex:GetAlpha() > 0.99, c.arrow.tex and c.arrow.tex:GetAlpha())
local okH, whyH = Flat(c.help); check("#468 the title bar's ? is flat", okH, whyH)

-------------------------------------------------------------------------------- #471
local PlatS = ns.Settings("platform"); PlatS.ui = PlatS.ui or {}; PlatS.ui.themeAdvanced = true   -- Advanced customization open (her screenshots)
ACD:SelectGroup("CueRules", "set", "ui", "theme"); W.tick(0.3, 6)
local function find(w, pred, out)
  out = out or {}
  if type(w) ~= "table" then return out end
  if pred(w) then out[#out + 1] = w end
  for _, ch in ipairs(w.children or {}) do find(ch, pred, out) end
  return out
end
local function optName(w) local o = w.GetUserData and w:GetUserData("option"); return o and o.name end
local box = find(of, function(w) return w.type == "MultiLineEditBox" and optName(w) == "Theme string" end)[1]
check("(the Theme page is drawn: its Theme string box)", box ~= nil)
if box then
  local okB, whyB = Flat(box.button)
  check("#471 item 1: the Theme string box's Accept button has the flat look", okB, whyB)
  check("#471 item 1: ...and still does what it did (its text and click are AceGUI's)", box.button:GetText() == ACCEPT and box.button:GetScript("OnClick") ~= nil, box.button:GetText())
end
local resets = find(of, function(w) return w.type == "Button" and optName(w) == "Reset" and w.frame:IsVisible() end)
check("(the class boxes' Reset buttons are drawn)", #resets >= 5, #resets)
local offs, inside, worst = {}, true, ""
for _, r in ipairs(resets) do
  local p = r.parent   -- the class box; inside = within its drawn border (AceGUI's InlineGroup lays out 1 px wider than its content frame)
  local bl, brt = p.content:GetLeft(), p.content:GetParent():GetRight()
  offs[#offs + 1] = r.frame:GetLeft() - bl
  if r.frame:GetRight() > brt - 0.5 or r.frame:GetLeft() < bl - 0.5 then inside = false; worst = ("Reset %.0f-%.0f, box %.0f-%.0f"):format(r.frame:GetLeft(), r.frame:GetRight(), bl, brt) end
end
local spread = 0
for _, o in ipairs(offs) do spread = math.max(spread, math.abs(o - offs[1])) end
check("#471 item 2: every Reset sits at the same x in its box (one column)", #offs > 0 and spread < 0.5, table.concat(offs, ", "))
check("#471 item 2: every Reset is inside its box", #resets > 0 and inside, worst)
local del = find(of, function(w) return w.type == "Button" and optName(w) == "Delete saved" end)[1]
local page = del and del.parent
if del and page then
  local edge = page.content:GetLeft() + (page.content.width or page.content:GetWidth())   -- the width the page lays its rows out in
  local gap = edge - del.frame:GetRight()
  -- (1 px of rounding allowed: the page's width can differ by under a pixel between the row's layout and this read)
  check("#471 item 3: \"Delete saved\" ends at least one margin (ns.Style.margin) inside the page's right edge", gap >= ns.Style.margin - 1.01,
    ("%.1f px from the edge"):format(gap))
  local save = find(of, function(w) return w.type == "Button" and optName(w) == "Save" end)[1]
  check("#471 item 3: ...on the same row as Save, after it", save and math.abs(save.frame:GetTop() - del.frame:GetTop()) < 0.5 and del.frame:GetLeft() > save.frame:GetRight())
else
  check("(the Delete saved button is drawn)", false)
end
check("#471 item 4 (window opacity) unchanged: default 0.62 (waits for C4)", (tonumber(PlatS.ui.skinAlpha) or 0.62) == 0.62)

-------------------------------------------------------------------------------- #483
local okc, ctx = pcall(ns.ReadContext)
local path = { ns.ScopePath(P, okc and ctx or nil) }
ACD:SelectGroup("CueRules", unpack(path)); W.tick(0.05, 8)
local function findG(t, seen)
  seen = seen or {}
  if type(t) ~= "table" or seen[t] then return end
  seen[t] = true
  if t.args and t.args.xuiSearch then return t end
  for _, v in pairs(t) do local r = findG(v, seen); if r then return r end end
end
local rg = findG(ns.OptionsApi.LastTree and ns.OptionsApi.LastTree())
check("(the rule's editor is open, with its search box)", rg ~= nil)
if not rg then return R end
local a = rg.args
-- the search box's Okay (shown while the text is changed) in the flat look
local sbox = find(of, function(w) return w.type == "EditBox" and optName(w) == "Search this rule's options" end)[1]
check("(the search box is drawn)", sbox ~= nil)
if sbox then local okO, whyO = Flat(sbox.button); check("#483 the search box's Okay button has the flat look", okO, whyO) end
-- the open rule's controls, by their AceConfig path under the rule ("cues>oq1>anim>body>glow"); visible = drawn and inside the visible
-- part of its scrolling page
local function Under(u)
  local p = u and u.path
  if type(p) ~= "table" then return nil end
  for i = 1, #p do if p[i] == path[#path] then return table.concat(p, ">", i + 1) end end
end
local function Ctl(sub)
  local hit, sc
  local function walk(w, s, d)
    if hit or type(w) ~= "table" or d > 40 then return end
    if w.type == "ScrollFrame" then s = w end
    local u = w.GetUserDataTable and w:GetUserDataTable()
    if u and u.option and u.option.type ~= "group" and Under(u) == sub and w.frame:IsVisible() then hit, sc = w, s; return end
    for _, ch in ipairs(w.children or {}) do walk(ch, s, d + 1) end
  end
  walk(of, nil, 0)
  return hit, sc
end
local function InView(sub)
  local w, sc = Ctl(sub)
  if not w then return false, "not drawn" end
  if not sc then return true, "drawn" end
  local t, b, vt, vb = w.frame:GetTop(), w.frame:GetBottom(), sc.scrollframe:GetTop(), sc.scrollframe:GetBottom()
  return (b >= vb - 0.5 and t <= vt + 0.5), ("control %.0f-%.0f, view %.0f-%.0f"):format(b, t, vb, vt)
end
local function Pick(q, want)
  a.xuiSearch.set(nil, q); W.tick(0.05, 4)
  for i = 1, 12 do
    local o = a["xuiSR" .. i]
    if not o.hidden() and o.name():find(want, 1, true) then return o end
  end
end
local function TabOpen()
  local segs = { "cooldowns", "enabledTab" }
  for seg in ns.RulesTreeStatus().selected:gmatch("[^\001]+") do segs[#segs + 1] = seg end
  local st = ACD:GetStatusTable("CueRules", segs); return st.groups and st.groups.selected
end
-- her case (screenshot 3): "glow", then a Cues result. Pulsing glow sits in the cue's Animation Options section, which starts closed.
local r1 = Pick("glow", "Pulsing glow")
check("(\"glow\" lists Cues > Pulsing glow)", r1 ~= nil)
if r1 then
  r1.func(); W.tick(0.05, 12)
  check("#483 the click opens the Cues tab", TabOpen() == "cues", TabOpen())
  check("#483 the results fold away (the note and every result row hidden)", a.xuiSearchNote.hidden() == true and a.xuiSR1.hidden() == true)
  check("#483 ...the typed text stays in the box, and Clear search stays", a.xuiSearch.get() == "glow" and a.xuiSearchClear.hidden() == false)
  local okV, whyV = InView("cues>oq1>anim>body>glow")
  check("#483 \"Pulsing glow\" is drawn and inside the visible part of the page (its section opened, scrolled to)", okV, whyV)
end
-- an option far down a long tab (Load: the zone list), from the top of the page
local r2 = Pick("/zone/", "Zones")
check("#483 Enter on the same text brings the results back", r2 ~= nil and a.xuiSearchNote.hidden() == false)
if r2 then
  -- the zone list's place under the rule, read from the options table (the test's own walk, not the search's index)
  local zkey
  local function walkKeys(args, pre, d)
    if zkey or type(args) ~= "table" or d > 12 then return end
    for k, o in pairs(args) do
      if type(o) == "table" then
        local nm = o.name; if type(nm) == "function" then local okn, v = pcall(nm, {}); nm = okn and v or nil end
        if o.type ~= "group" and type(nm) == "string" and nm:find("Zones", 1, true) then zkey = pre .. ">" .. k; return end
        if o.type == "group" then walkKeys(o.args, pre .. ">" .. k, d + 1) end
      end
    end
  end
  walkKeys(a.load and a.load.args, "load", 0)
  r2.func(); W.tick(0.05, 12)
  check("#483 the click opens the Load tab", TabOpen() == "load", TabOpen())
  local okZ, whyZ = InView(zkey or "?")
  check("#483 the zone list is inside the visible part of the Load page", okZ, tostring(zkey) .. ": " .. whyZ)
end
a.xuiSearchClear.func(); W.tick(0.05, 4)
check("#483 Clear search empties the box and hides the results", a.xuiSearch.get() == "" and a.xuiSR1.hidden() == true)

-------------------------------------------------------------------------------- release (AceGUI recycles the window for other addons)
pcall(ns.ToggleUI); W.tick(0.05, 4)
local AceGUI = LibStub("AceGUI-3.0")
if ACD.OpenFrames and ACD.OpenFrames.CueRules then ACD:Close("CueRules"); W.tick(0.05, 2) end
check("#468 released to AceGUI: the Close button is AceGUI's stock one again (for the next addon that gets this window)", closeBtn and Stock(closeBtn))
if box then check("#471 released: the multi-line box's Accept is stock again", Stock(box.button)) end
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
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
