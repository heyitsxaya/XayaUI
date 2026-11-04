#!/usr/bin/env python3
"""Xaya 2026-11-04 (screenshot of an Icon cue): "icon options should have their own nested text options to display things like
progress / duration; stacks; absorb values; etc". An Icon or Texture cue's Text section (buff duration text, stacks / charges count,
shield / absorb amount) is inside its Icon / Texture Options box (Options 0.6.28); before, it sat below Position / Color / Animation.
Builds the real settings tree in the stand-in game with a rule holding an Icon, a Texture and a Text cue.
Run: python3 tests/icon_cue_text_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useBuff = true; P.buffID = 203819; P.buffState = "present"; ns.NormalizeRule(P)
ns.rules = { P }
local icon, tex, txt = ns.NewCueRule(P, "icon"), ns.NewCueRule(P, "texture"), ns.NewCueRule(P, "text")
local built = ns.BuildOptionsTable()
local function findAll(root, pred)
  local out, seen, stack = {}, {}, { root }
  while #stack > 0 do
    local t = table.remove(stack)
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      if pred(t) then out[#out + 1] = t end
      for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
    end
  end
  return out
end
local function has(root, key) return #findAll(root, function(t) return type(t.args) == "table" and t.args[key] ~= nil end) > 0 end
-- each cue's group on its rule's Cues tab: the one whose box is named "Icon Options" / "Texture Options"
local function box(name) return findAll(built, function(t) return type(t.args) == "table" and type(t.args.tex) == "table" and t.args.tex.name == name end)[1] end
local gI, gT = box("Icon Options"), box("Texture Options")
check("the Icon and the Texture cue each have their options box", gI ~= nil and gT ~= nil)
if not (gI and gT) then return R end
for _, pair in ipairs({ { "Icon", gI }, { "Texture", gT } }) do
  local nm, g = pair[1], pair[2]
  local nested = g.args.tex.args.xuiTextNested
  check(nm .. " cue: the Text section is inside its options box", nested ~= nil)
  check(nm .. " cue: ...with buff duration text, stacks / charges and absorb", nested and has(nested, "dur") and has(nested, "cnt") and has(nested, "abs"))
  check(nm .. " cue: ...after the box's own art and size sections", nested and nested.order == 900)
  check(nm .. " cue: no second Text section below the box", g.args.text == nil)
end
check("the two cues' boxes are separate tables (the shared art options are not changed for other panes)",
  gI.args.tex.args ~= gT.args.tex.args and #findAll(built, function(t) return type(t.args) == "table" and t.args.xuiTextNested ~= nil end) == 2)
local tTxt = findAll(built, function(t) return type(t.args) == "table" and t.args.txt_dur ~= nil end)[1]
check("a Text cue keeps its text options laid out flat, as before", tTxt ~= nil and tTxt.args.xuiTextNested == nil)
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
