#!/usr/bin/env python3
"""UI-51 / UI-52 (BUILD-RULES B3, order UI-55 "Baseline, refactor, test"): moving hand-drawn hovers onto the shared tooltip helper
(core ns.Tip) must not change a single tooltip.

How: the real addons start in the stand-in game (every addon on, settings window loaded, movers unlocked, the minimap list open).
Then every frame with a mouse-over script is hovered once (OnEnter, then OnLeave). Every call it makes on GameTooltip is recorded:
method, arguments, and whether the owner is the hovered frame. Numbers are rounded to 3 places; frames show as "<owner>" / "<frame>".
The sorted list of those call logs must equal tests/tooltip_parity_golden.json, which was recorded on the code BEFORE the refactor
(origin/main 8478204, re-recorded there when main was merged in; first recorded on f649428). So any hover whose text, colour, wrap, anchor or order changed fails here.
(Main slim-down, Rules 0.7.0: main holds XayaUI, XayaUI_Options and XayaUI_Rules only. The golden was re-recorded then: the new recording
equals the old golden minus exactly the 15 hovers the retired addons drew (XayaUI_Chat's 12 and XayaUI_Bonus's Calculator / Notes /
Data Panels minimap rows); every hover of core, Options and Rules was unchanged.)
(Bundle 1 round 11a, 2026-11-18: re-recorded for the arithmetic Calculator's own minimap row, SD-115 / SD-116, XayaUI_Bonus/Calculator.lua.
The recording of round 10's code (dd80f897) equals the recording of 68432825, round 9's end, which equals the old golden, plus exactly one
hover, "Calculator" (ANCHOR_RIGHT, title gold 1.000/0.820/0.000, line "Show or hide the calculator (also /xui calc)"): 14 -> 15 hovers,
none gone or changed.)
It also checks that the hovers of the converted files are in the recording (so the comparison covers them), and that ns.Tip exists.
A failure names the hovers behind it (title and anchor; for a changed hover, its first differing call), and a self-check proves that naming.

Re-record (only for a deliberate change to a hover, never to make a refactor pass): python3 tests/tooltip_parity_run.py --record
Run: python3 tests/tooltip_parity_run.py   (Lua 5.1 via lupa)."""
import collections, json, os, sys
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
# (the minimap list's rows are core's: the XayaUI Settings row is the one core registers itself; the other rows came from retired addons)
COVERS = [
    ("core MinimapButton.lua (button)", "Left-click: quick-access list"),
    ("core MinimapButton.lua (list rows)", "SetText|XayaUI Settings|1.000|0.820|0.000"),
    ("Rules Visual.lua (group tag)", "display(s) on screen"),
    ("Rules Visual.lua (group lock)", "Lock this group for now"),
]


# files whose every hover is drawn by ns.Tip (Rules Visual.lua is converted for its group tags only: its rule tag and the
# spell / item tooltip stay direct, the first because no rule with a display exists in the stand-in to record it)
CONVERTED = ["XayaUI/MinimapButton.lua"]


def record():
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    logs = sorted(str(res.logs[i]) for i in range(1, len(res.logs) + 1))
    errs = [str(world.errors[i])[:400] for i in range(1, len(world.errors) + 1)]
    return logs, bool(res.tip), errs


def hover_name(log):
    """A hover's readable name: its title (the first SetText, else the first AddLine) and its anchor, e.g. "Calculator (ANCHOR_RIGHT)"."""
    calls = log.split("\n")
    anchor = next((c.split("|")[2] for c in calls if c.startswith("SetOwner|") and c.count("|") >= 2), "no anchor")
    title = next((c.split("|")[1] for c in calls if c.startswith("SetText|") and c.count("|") >= 1), None)
    if title is None:
        title = next((c.split("|")[1] for c in calls if c.startswith("AddLine|") and c.count("|") >= 1), "<no text>")
    return "%s (%s)" % (title, anchor)


def name_hover_differences(logs, want):
    """Names WHICH hovers differ from the golden (round 11a: a stale golden must be diagnosable). Compared as multisets (the same hover
    can be drawn by several frames, e.g. four group locks). A recorded and a golden hover with the same name are reported as one
    "changed" hover with its first differing call; the rest are "new" or "gone"."""
    extra = collections.Counter(logs) - collections.Counter(want)
    gone = collections.Counter(want) - collections.Counter(logs)
    gone_by_name = collections.defaultdict(list)
    for w in sorted(gone.elements()):
        gone_by_name[hover_name(w)].append(w)
    out = []
    for g in sorted(extra.elements()):
        name = hover_name(g)
        if gone_by_name.get(name):
            w = gone_by_name[name].pop(0)
            a, b = w.split("\n"), g.split("\n")
            i = next((i for i in range(max(len(a), len(b))) if (a[i:i + 1] or [None]) != (b[i:i + 1] or [None])), 0)
            out.append("changed: %s, call %d: golden %r, now %r" % (name, i + 1, (a[i:i + 1] or ["(none)"])[0], (b[i:i + 1] or ["(none)"])[0]))
        else:
            out.append("new: " + name)
    for name, rest in sorted(gone_by_name.items()):
        out += ["gone: " + name for _ in rest]
    return sorted(out)


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
    want = sorted(json.load(open(GOLDEN, encoding="utf-8")))
    # (round 11a) every failure below names the hovers behind it (title and anchor; for a changed one, its first differing call)
    named = name_hover_differences(logs, want)
    check("hovers recorded: %d (golden: %d)" % (len(logs), len(want)), len(logs) == len(want), "; ".join(named))
    missing = [w for w in want if w not in logs]
    extra = [g for g in logs if g not in want]
    check("every hover draws exactly the tooltip it drew before the refactor (same calls, arguments, order)",
          not missing and not extra and not named, "; ".join(named))
    # the naming itself, on this run's real recording: one hover's text changed, one gone and one new must each be named, nothing else
    if len(logs) >= 3:
        first = logs[0]
        second = next((l for l in logs if hover_name(l) != hover_name(first)), first)
        lines = first.split("\n")
        k = next(i for i, c in enumerate(lines) if c.startswith("SetText|") or c.startswith("AddLine|"))
        changed = "\n".join(lines[:k + 1] + ["AddLine|self-check text"] + lines[k + 1:])
        fake = "SetOwner|<owner>|ANCHOR_TOP\nSetText|Self-check hover\nShow\n--leave--\nHide"
        mutated = [changed] + [l for l in logs[1:] if l not in (first, second)] + [first] * (logs.count(first) - 1) + [fake]
        got_names = name_hover_differences(mutated, logs)
        want_names = sorted(["changed: %s, call %d: golden %r, now %r" % (hover_name(first), k + 2, (lines[k + 1:k + 2] or ["(none)"])[0],
                             "AddLine|self-check text"), "new: Self-check hover (ANCHOR_TOP)"] + ["gone: " + hover_name(second)] * logs.count(second))
        check("a failed comparison names the hover that changed, the one that is gone and the one that is new (self-check on the real recording)",
              got_names == want_names, "got %s want %s" % (got_names, want_names))
    for label, text in COVERS:
        check("the recording covers %s" % label, any(text in g for g in logs))
    check("core has the shared tooltip helper ns.Tip (Show, Hide)", tip)
    root = os.path.abspath(os.path.join(HERE, ".."))
    for rel in CONVERTED:
        code = "\n".join(l.split("--", 1)[0] for l in open(os.path.join(root, rel), encoding="utf-8").read().split("\n"))
        check("%s draws its hovers through ns.Tip only (no direct GameTooltip call left)" % rel, "GameTooltip" not in code)
    for e in errs:
        print("ERROR in the game stand-in:", e)
    check("no Lua errors", not errs, errs[:2])
    print("%d failed" % len(fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
