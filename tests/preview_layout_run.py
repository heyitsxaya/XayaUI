#!/usr/bin/env python3
"""Offline test (core 0.6.3, #344 and the 2026-11-03 preview reports): a dynamic group lays out ONE slot per rule, in the rules' own
list order (the sidebar order), not one slot per cue in the order the cues were created; a rule's second display cue (a separate Text
cue) sits on that rule's slot instead of taking a slot of its own; moving a rule up / down moves its slot.
Synthetic data shaped like a real report (rules and their cues interleaved, cues made in a different order than the rules).
Optional: --export FILE  also runs the same checks on a group export (XUI1 string); never commit such a file.
Run: python3 tests/preview_layout_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import base64, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, SRC)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (extra and ("  [" .. tostring(extra) .. "]") or ""), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
if ns.ToggleUI then pcall(ns.ToggleUI) end   -- the settings window open, as when the eye icon is used (previews end when it closes)
W.tick(0.1, 2)
ns = rawget(_G, "XayaUI_NS")
local function new(t) local r = ns.NewRule(); for k, v in pairs(t) do r[k] = v end; ns.NormalizeRule(r); return r end
local folderId
if SRC then
  ns.folders = SRC.folders; ns.rules = {}
  for _, r in ipairs(SRC.rules) do ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r end
  folderId = SRC.folders[1].id
else
  ns.folders = { { id = "fD", name = "Dyn", cType = "dynamic", cGrowth = "DOWN", cSpacing = 4 } }
  folderId = "fD"
  local function parent(n) return new({ name = n, uid = "u" .. n, folder = "fD", enabled = true, useBuff = true, buffID = 1000 + #n, buffState = "present" }) end
  local function cue(p, kind, extra)
    local c = new({ name = p.name .. " (cue)", isCue = true, cueKind = kind, cueKey = "q" .. kind, parentUid = p.uid, folder = "fD", enabled = true })
    c.visual.enabled = true; c.visual.trigger = "condition"; c.visual.w = 30; c.visual.h = 30
    if kind == "icon" then c.visual.kind = "spellicon" end
    if kind == "text" then c.visual.w = 128; c.visual.h = 128; c.visual.text.enabled = true end
    return c
  end
  local A, B, C, D = parent("A"), parent("B"), parent("C"), parent("D")
  -- list order: rules A, B, C, D; their icon cues made in the order D, B, A, C (as cues are appended when made); A also has a Text cue
  ns.rules = { cue(D, "icon"), A, cue(B, "icon"), B, cue(A, "icon"), C, cue(C, "icon"), D, cue(A, "text") }
end
-- preview every rule of the group (the eye icon), which draws every display cue
local list = {}   -- what the group's eye icon previews: each rule's preview targets (its display cues; the rule itself only without cues)
for _, r in ipairs(ns.rules) do
  if r.folder == folderId and not r.parentUid then for _, t in ipairs(ns.PreviewTargets(r)) do list[#list + 1] = t end end
end
ns.SetPreview(list, "visual", true)
for _, r in ipairs(ns.rules) do if r.isCue then pcall(ns.RefreshVisual, r) end end
W.tick(0.1, 3)
local function framesOf(rule) return ns.VisualFramesOf and ns.VisualFramesOf(rule) or {} end
local function pt(fr) local p = fr and fr._pts and fr._pts[1]; if not p then return nil end return p[4] or 0, p[5] or 0 end
-- the rules (parents) of the group in list order, and the y of each one's first display frame (DOWN: 0, -34, -68, ...)
local parents = {}
for _, r in ipairs(ns.rules) do if r.folder == folderId and not r.parentUid then parents[#parents + 1] = r end end
local function slotY(p)
  for _, c in ipairs(ns.CuesOf(p)) do
    local fr = framesOf(c)[1]
    if fr and fr:IsShown() and c.visual.enabled and c.cueKind ~= "text" then local _, y = pt(fr); return y end
  end
  for _, c in ipairs(ns.CuesOf(p)) do local fr = framesOf(c)[1]; if fr and fr:IsShown() then local _, y = pt(fr); return y end end
end
local function orderOK()
  local last, n = nil, 0
  for _, p in ipairs(parents) do
    local y = slotY(p)
    if y ~= nil then
      n = n + 1
      if last and not (y < last) then return false, p.name .. " y=" .. tostring(y) .. " after " .. tostring(last) end
      last = y
    end
  end
  return n > 0, "slots " .. n
end
local ok, why = orderOK()
check("slots follow the rules' list order (the sidebar), top to bottom", ok, why)
-- every slot is distinct: one per rule, so the number of different y values equals the number of rules that show something
local ys, nShow = {}, 0
for _, p in ipairs(parents) do local y = slotY(p); if y ~= nil then nShow = nShow + 1; ys[tostring(y)] = true end end
local nY = 0; for _ in pairs(ys) do nY = nY + 1 end
check("one slot per rule (no slot for a second cue)", nY == nShow, nY .. " slots for " .. nShow .. " rules")
-- a rule's other display cue (a Text cue) sits on its rule's slot, not below the last rule
local textOK, seen = true, false
for _, p in ipairs(parents) do
  local y0 = slotY(p)
  for _, c in ipairs(ns.CuesOf(p)) do
    if c.cueKind == "text" then
      local fr = framesOf(c)[1]
      if fr and fr:IsShown() then seen = true; local _, y = pt(fr); if y ~= y0 then textOK = false end end
    end
  end
end
check("a rule's separate Text cue sits on that rule's slot", seen and textOK, seen and "" or "no text cue in the data")
-- moving the first rule down one place (the sidebar arrow swaps two rules in the list) moves its slot
local p1, p2 = parents[1], parents[2]
local i1, i2
for i, r in ipairs(ns.rules) do if r == p1 then i1 = i elseif r == p2 then i2 = i end end
ns.rules[i1], ns.rules[i2] = ns.rules[i2], ns.rules[i1]
local okR, errR = pcall(ns.RefreshAllVisuals)
W.tick(0.1, 2)
local shownN = 0
for _, r in ipairs(ns.rules) do local fr = framesOf(r)[1]; if fr and fr:IsShown() then shownN = shownN + 1 end end
local nPv = 0; for _ in pairs(ns.previewSets.visual) do nPv = nPv + 1 end
check("redraw after the swap runs and keeps the previews shown", okR and shownN > 0, tostring(errR) .. " shown=" .. shownN .. " previewing=" .. nPv)
local y1, y2 = slotY(p1), slotY(p2)
check("after swapping the first two rules, the second rule's slot is now above the first's", y1 and y2 and y2 > y1, tostring(y1) .. " / " .. tostring(y2))
check("and the slots are packed (30 px icons + 4 px spacing: 0 and -34)", y2 == 0 and y1 == -34, tostring(y2) .. " / " .. tostring(y1))
check("no Lua errors", #W.errors == 0, W.errors[1])
return R
end
'''


def load_export(path):
    s = open(path).read().strip()
    d = json.loads(base64.b64decode(s.split(":", 2)[2]))
    return d


def main():
    src = None
    if "--export" in sys.argv:
        src = load_export(sys.argv[sys.argv.index("--export") + 1])
    folders = H.find_addons()
    enabled = ["XayaUI", "XayaUI_Rules", "XayaUI_Media", "XayaUI_Options", "XayaUI_Rules_Options"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), H.to_lua(L, {}))
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld, S) return loadstring(src)()(W, Ld, S) end")(LUA, world, loader, H.to_lua(L, src) if src else None)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(res), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
