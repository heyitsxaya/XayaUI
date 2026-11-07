#!/usr/bin/env python3
"""UI-51 / UI-52 (BUILD-RULES B3, order UI-55 "Baseline, refactor, test"): moving hand-drawn hovers onto the shared tooltip helper
(core ns.Tip) must not change a single tooltip.

How: the real addons start in the stand-in game (every addon on, settings window loaded, movers unlocked, the minimap list open).
Then every frame with a mouse-over script is hovered once (OnEnter, then OnLeave). Every call it makes on GameTooltip is recorded:
method, arguments, and whether the owner is the hovered frame. Numbers are rounded to 3 places; frames show as "<owner>" / "<frame>".
The sorted list of those call logs must equal tests/tooltip_parity_golden.json, which was recorded on the code BEFORE the refactor
(claude/ui-bugs-focused 544961e). So any hover whose text, colour, wrap, anchor or order changed fails here.
It also checks that the hovers of the converted files are in the recording (so the comparison covers them), and that ns.Tip exists.

Re-record (only for a deliberate change to a hover, never to make a refactor pass): python3 tests/tooltip_parity_run.py --record
Run: python3 tests/tooltip_parity_run.py   (Lua 5.1 via lupa)."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

GOLDEN = os.path.join(HERE, "tooltip_parity_golden.json")

LUA = r'''
return function(W, L)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
-- states that make more hovers exist: the mover view, the minimap quick-access list, the settings window
if ns.ToggleUnlock then pcall(ns.ToggleUnlock) elseif SlashCmdList and SlashCmdList.XAYAUI then pcall(SlashCmdList.XAYAUI, "unlock") end
W.tick(0.1, 5)
if ns.ToggleUI then pcall(ns.ToggleUI) end; W.tick(0.1, 5)
local mb = rawget(_G, "XayaUIMinimapButton")
if mb and mb._scripts.OnClick then pcall(mb._scripts.OnClick, mb, "LeftButton") end; W.tick(0.1, 3)
local GT = GameTooltip
local log
local hovered
local function enc(v)
  local t = type(v)
  if t == "number" then return string.format("%.3f", v) end
  if t == "string" then return v end
  if t == "boolean" then return tostring(v) end
  if t == "nil" then return "nil" end
  if t == "table" then if v == hovered then return "<owner>" end return "<frame>" end
  return "<" .. t .. ">"
end
local METHODS = { "SetOwner", "SetText", "AddLine", "AddDoubleLine", "ClearLines", "Show", "Hide", "SetMinimumWidth",
  "SetSpellByID", "SetItemByID", "SetHyperlink", "SetInventoryItem", "SetBagItem", "AddTexture", "SetPoint", "ClearAllPoints" }
local orig = {}
for _, m in ipairs(METHODS) do
  orig[m] = GT[m]
  rawset(GT, m, function(self, ...)
    if log and self == GT then
      local parts = { m }
      local n = select("#", ...)
      for i = 1, n do parts[#parts + 1] = enc((select(i, ...))) end
      log[#log + 1] = table.concat(parts, "|")
    end
    local f = orig[m]
    if f then return f(self, ...) end
  end)
end
local out = {}
local seen = {}
local objs = {}
for i = 1, #W.objects do objs[i] = W.objects[i] end
for _, o in ipairs(objs) do
  local enter = o._scripts and o._scripts.OnEnter
  if enter and not seen[o] then
    seen[o] = true
    hovered = o
    log = {}
    pcall(enter, o, false)
    local leave = o._scripts.OnLeave
    if leave then log[#log + 1] = "--leave--"; pcall(leave, o, false) end
    local used = false
    for _, line in ipairs(log) do if line:find("^SetOwner") or line:find("^SetText") or line:find("^AddLine") then used = true end end
    if used then out[#out + 1] = table.concat(log, "\n") end
    log = nil
  end
end
for _, m in ipairs(METHODS) do rawset(GT, m, nil) end
return { logs = out, tip = type(ns.Tip) == "table" and type(ns.Tip.Show) == "function" and type(ns.Tip.Hide) == "function",
  errors = #W.errors }
end
'''

# text that only the converted hovers draw: each must be in the recording, or the comparison does not cover that file
COVERS = [
    ("core MinimapButton.lua (button)", "Left-click: quick-access list"),
    ("core MinimapButton.lua (list rows)", "SetText|Settings|1.000|0.820|0.000"),
    ("core Visual.lua (group tag)", "display(s) on screen"),
    ("core Visual.lua (group lock)", "Lock this group for now"),
    ("Chat History.lua", "SetText|Chat history"),
    ("Chat Bar.lua (data blocks)", "SetText|Friends online"),
    ("Chat Privacy.lua", "Chat privacy"),
    ("Chat Frame.lua (collapse arrow)", "the chat"),
]


def record():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    logs = sorted(res.logs[i] for i in range(1, len(res.logs) + 1))
    errs = [str(world.errors[i])[:400] for i in range(1, len(world.errors) + 1)]
    return logs, bool(res.tip), errs


def main():
    logs, tip, errs = record()
    if "--record" in sys.argv:
        json.dump(logs, open(GOLDEN, "w", encoding="utf-8"), indent=1)
        print("recorded %d hovers into %s" % (len(logs), os.path.relpath(GOLDEN)))
        for e in errs:
            print("ERROR in the game stand-in:", e)
        sys.exit(1 if errs else 0)
    fails = []

    def check(name, ok, extra=""):
        print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra)[:900] + "]"))
        if not ok:
            fails.append(name)
    want = json.load(open(GOLDEN, encoding="utf-8"))
    check("hovers recorded: %d (golden: %d)" % (len(logs), len(want)), len(logs) == len(want))
    missing = [w for w in want if w not in logs]
    extra = [g for g in logs if g not in want]
    check("every hover draws exactly the tooltip it drew before the refactor (same calls, arguments, order)",
          not missing and not extra, "changed/missing: %s || new: %s" % (missing[:2], extra[:2]))
    for label, text in COVERS:
        check("the recording covers %s" % label, any(text in g for g in logs))
    check("core has the shared tooltip helper ns.Tip (Show, Hide)", tip)
    for e in errs:
        print("ERROR in the game stand-in:", e)
    check("no Lua errors", not errs, errs[:2])
    print("%d failed" % len(fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
