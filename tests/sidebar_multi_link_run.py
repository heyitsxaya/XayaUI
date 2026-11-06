#!/usr/bin/env python3
"""Offline test (Options 0.6.53): the sidebar's own icons and the multi-select bar / menu. Xaya, 2026-11-06:
- "change lock icon to be simpler and flatter"; "use the more common color choice for the lock and use the less common color for the
  mover icon (also flatten)": the movement lock shows XayaUI's own white padlock, an unlocked row its own gold four-way arrow;
- "clear should be "Deselect (#)"", "Delete should have (#) and Move to should be relabeled to say Move / Move (#)": with 2 rules
  selected the bar reads "Delete (2)", "Move (2)", "Deselect (2)", each label inside its button;
- "linking aura functionality not possible in the drop down menu" (her answer "Link N selected"): the right-click menu of a selected
  row offers "Link 2 Selected (move together)", which links the selected rules' displays (dragging one moves the others); then
  "Unlink 2 Selected" undoes it.
Run: python3 tests/sidebar_multi_link_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, struct, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402
REPO = os.path.dirname(HERE)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
local function rule(name, id)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, id, "present"
  r.visual.enabled, r.sound.enabled = false, false
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
ns.rules = {}
local A, B = rule("R - Demon Spikes", 1001), rule("L - Calcified Spikes", 1002)
local ca, cb = ns.NewCueRule(A, "icon"), ns.NewCueRule(B, "icon")
if ns.ToggleUI then pcall(ns.ToggleUI) end
W.tick(0.1, 4)
ns = rawget(_G, "XayaUI_NS")
-- the sidebar rows of A and B
local rows = {}
local function walk(f, d)
  if not f or d > 60 then return end
  local uv = f.uniquevalue and tostring(f.uniquevalue):match("([^\001]+)$")
  local n = uv and tonumber(uv:match("^rule(%d+)$"))
  if n and f:IsShown() and ns.rules[n] then rows[ns.rules[n]] = rows[ns.rules[n]] or f end
  for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
end
walk(UIParent, 0)
check("the two rules have sidebar rows", rows[A] ~= nil and rows[B] ~= nil)
if not (rows[A] and rows[B]) then return R end
-- the movement lock: our own white padlock while the row is locked for moving
local mv = rows[A].xuiMove
local mt = mv and mv.tex and tostring(mv.tex:GetTexture())
check("movement lock: XayaUI's own padlock (not the game's pet-battle lock)", mt == ns.LOCK_ICON and ns.LOCK_ICON:find("XayaUI\\Media\\UI\\xui_lock.tga", 1, true) ~= nil, mt)
check("the mover picture is XayaUI's own four-way arrow", ns.MOVE_ICON and ns.MOVE_ICON:find("XayaUI\\Media\\UI\\xui_move.tga", 1, true) ~= nil)
-- select both (Ctrl+click)
IsControlKeyDown = function() return true end
ns.MultiClick(rows[A], "LeftButton"); ns.MultiClick(rows[B], "LeftButton")
IsControlKeyDown = function() return false end
if ns.DecorateTrees then ns.DecorateTrees() end
W.tick(0.1, 2)
check("two rules selected", ns.MultiCount() == 2)
local bar
local function findBar(f, d) if not f or d > 60 or bar then return end; if f.xuiSelBar then bar = f.xuiSelBar end; for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do findBar(c, d + 1) end end
findBar(UIParent, 0)
if not bar then
  -- the bar hangs off the tree widget (an AceGUI table, not a frame child): look in the open window's widgets
  local ACD = LibStub("AceConfigDialog-3.0")
  local function ww(w, d) if not w or d > 40 or bar then return end; if w.xuiSelBar then bar = w.xuiSelBar end; for _, c in ipairs(w.children or {}) do ww(c, d + 1) end end
  ww(ACD.OpenFrames["CueRules"], 0)
end
check("the selection bar is shown", bar ~= nil and bar:IsShown())
if bar then
  local d, m, c = bar.del:GetText(), bar.mv:GetText(), bar.clr:GetText()
  check("her labels: 'Delete (2)', 'Move (2)', 'Deselect (2)'", d == "Delete (2)" and m == "Move (2)" and c == "Deselect (2)", tostring(d) .. " | " .. tostring(m) .. " | " .. tostring(c))
  local fits = true
  for _, b in ipairs({ bar.del, bar.mv, bar.clr }) do
    local fs = b:GetFontString()
    local tw = fs and fs:GetStringWidth() or (#b:GetText() * 7)
    if tw > b:GetWidth() - 4 then fits = false end
  end
  check("each label fits inside its button (estimated font width)", fits)
  check("the buttons sit left to right without overlapping, inside the bar", bar.del:GetRight() <= bar.mv:GetLeft() + 0.5 and bar.mv:GetRight() <= bar.clr:GetLeft() + 0.5
    and bar.clr:GetRight() <= bar:GetRight() + 0.5 and bar.del:GetLeft() >= bar:GetLeft() - 0.5)
end
-- the right-click menu of a selected row
local labels, funcs = {}, {}
local function rec()
  local root = {}
  function root:CreateButton(text, fn) labels[#labels + 1] = tostring(text); funcs[tostring(text)] = fn; return rec() end
  function root:CreateTitle(t) labels[#labels + 1] = "#" .. tostring(t); return rec() end
  function root:CreateDivider() end
  function root:CreateRadio() return rec() end
  function root:CreateCheckbox() return rec() end
  function root:SetScrollMode() end
  return root
end
MenuUtil.CreateContextMenu = function(owner, gen) gen(owner, rec()) end
local function menu() labels, funcs = {}, {}; local h = rows[A]:GetScript("OnClick"); rows[A]:Click("RightButton") end
menu()
local has = funcs["Link 2 Selected (move together)"] ~= nil
check("the menu of a selected row offers 'Link 2 Selected (move together)'", has, table.concat(labels, ", "))
if has then funcs["Link 2 Selected (move together)"]() end
check("Link joins the two rules' displays (their icon cues share one link)", ca.link ~= nil and ca.link == cb.link and A.link == nil and B.link == nil)
menu()
check("then the menu offers 'Unlink 2 Selected', which undoes it", funcs["Unlink 2 Selected"] ~= nil, table.concat(labels, ", "))
if funcs["Unlink 2 Selected"] then funcs["Unlink 2 Selected"]() end
check("unlinked: neither display is linked any more", ca.link == nil and cb.link == nil)
ns.MultiClear()
menu()
local any = false
for _, l in ipairs(labels) do if l:find("Link", 1, true) then any = true end end
check("with nothing selected the menu has no Link line", not any, table.concat(labels, ", "))
return R
end
'''


def tga_ok(rel):
    path = os.path.join(REPO, rel)
    tracked = subprocess.run(["git", "ls-files", "--error-unmatch", path], cwd=REPO, capture_output=True).returncode == 0
    if not (tracked and os.path.exists(path)):
        return False
    h = open(path, "rb").read(18)
    w, hh = struct.unpack("<HH", h[12:16])
    return h[2] == 2 and w == 64 and hh == 64 and h[16] == 32 and (h[17] & 0x0F) == 8


def main():
    bad, n = 0, 0
    for f in ("xui_lock.tga", "xui_move.tga"):
        n += 1
        ok = tga_ok("XayaUI/Media/UI/" + f)
        print(("ok  " if ok else "FAIL: ") + "XayaUI/Media/UI/%s is in the repository: 64 x 64, 32-bit, alpha" % f)
        bad += 0 if ok else 1
    folders = H.find_addons()
    enabled = [x for x in folders if x != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        n += 1
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
