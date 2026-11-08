#!/usr/bin/env python3
"""UI-51 / UI-52 (BUILD-RULES B3, order UI-55 "Baseline, refactor, test"): moving hand-drawn hovers onto the shared tooltip helper
(core ns.Tip) must not change a single tooltip.

How: the real addons start in the stand-in game (every addon on, settings window loaded, movers unlocked, the minimap list open).
Then every frame with a mouse-over script is hovered once (OnEnter, then OnLeave). Every call it makes on GameTooltip is recorded:
method, arguments, and whether the owner is the hovered frame. Numbers are rounded to 3 places; frames show as "<owner>" / "<frame>".
The sorted list of those call logs must equal tests/tooltip_parity_golden.json, which was recorded on the code BEFORE the refactor
(origin/main 8478204, re-recorded there when main was merged in; first recorded on f649428). So any hover whose text, colour, wrap, anchor or order changed fails here.
It also checks that the hovers of the converted files are in the recording (so the comparison covers them), and that ns.Tip exists.

Re-record (only for a deliberate change to a hover, never to make a refactor pass): python3 tests/tooltip_parity_run.py --record
Run: python3 tests/tooltip_parity_run.py   (Lua 5.1 via lupa)."""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

GOLDEN = os.path.join(HERE, "tooltip_parity_golden.json")

LUA = r'''
return function(W, L)
-- (P4) the stand-in has one more addon folder since the split (XayaUI_Rules; P4b: and XayaUI_Rules_Options); it reports 0 KB for them, so the latency hover's memory list
-- (the eight biggest, all 1.0 MB in the stand-in) shows the same addons and total as the golden. The hover's own code is unchanged.
do local realMem = GetAddOnMemoryUsage
  GetAddOnMemoryUsage = function(a) local n = type(a) == "number" and C_AddOns.GetAddOnInfo(a) or a; if n == "XayaUI_Rules" or n == "XayaUI_Rules_Options" then return 0 end; return realMem(a) end end
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
    ("core MinimapButton.lua (list rows)", "SetText|Data Panels|1.000|0.820|0.000"),
    ("core Visual.lua (group tag)", "display(s) on screen"),
    ("core Visual.lua (group lock)", "Lock this group for now"),
    ("Chat History.lua", "SetText|Chat history"),
    ("Chat Bar.lua (data blocks)", "SetText|Friends online"),
    ("Chat Privacy.lua", "Chat privacy"),
    ("Chat Frame.lua (collapse arrow)", "the chat"),
]


# files whose every hover is drawn by ns.Tip (core Visual.lua is converted for its group tags only: its rule tag and the
# spell / item tooltip stay direct, the first because no rule with a display exists in the stand-in to record it)
# XayaUI_Chat is a QA-branch module (absent on main). The golden was recorded with it, so without it the expected recording is the golden
# without the hovers Chat draws: these (title, first line under it) pairs, 12 in all (the Chat History / Chat Panel / Improved Chat /
# privacy / Chat windows / Newest message / Hide the chat buttons and the Chat Bar's blocks: XayaUI, Friends online, Latency, Time).
CHAT_HOVERS = {
    ("SetText|Chat history", "AddLine|Copy recent messages"),
    ("SetText|Chat Panel", "AddLine|Open the Chat Panel settings (also /xui chat settings)"),
    ("SetText|Chat privacy", "AddLine|Click: cover the chat"),
    ("SetText|Chat privacy cover", "AddLine|Cover or show the chat (also /xui privacy)"),
    ("SetText|Chat windows", "AddLine|Lists every chat window; click one to switch to it."),
    ("SetText|Improved Chat", "AddLine|Open the Improved Chat settings"),
    ("SetText|Newest message", "AddLine|Scrolls the chat to its newest line."),
    ("SetText|XayaUI", "AddLine|Left-click: the quick-access list. Right-click: settings."),
    ("SetText|Friends online", "AddLine|Game friends: 3"),
    ("SetText|Hide the chat", "Show"),
    ("SetText|Latency", "AddLine|Home: 20 ms"),
    ("SetText|Time", "AddLine|<DATE>"),
}
HAS_CHAT = os.path.isdir(os.path.join(os.path.dirname(HERE), "XayaUI_Chat"))
# The Chat Bar's Latency hover lists each loaded XayaUI addon's memory (the stand-in gives every addon the same size) under their total,
# capped to a few lines. The golden was recorded with every module loaded; on main (tools/qa-only-paths.txt) the absent ones are not
# loaded, so for this one hover: the absent addons' lines are dropped, the total is lowered by one size per absent addon (each was
# loaded when the golden was recorded, listed or not), and the addon lines are compared as a set (equal sizes have no fixed order).
# Every other line of it, and every other hover, is still compared exactly.
ABSENT_ADDONS = [a for a in ("XayaUI_Chat", "XayaUI_Reskin", "XayaUI_Nameplates")
                 if not os.path.isdir(os.path.join(os.path.dirname(HERE), a))]
USAGE_LINE = re.compile(r"^AddLine\|([0-9.]+) MB   ([^|\s]+)\|")


def usage_sorted(g):
    """the Latency hover with its addon lines in sorted order (other hovers unchanged)"""
    if "\nSetText|Latency\n" not in g:
        return g
    ls = g.split("\n")
    idx = [i for i, l in enumerate(ls) if USAGE_LINE.match(l)]
    block = sorted(ls[i] for i in idx)
    for i, l in zip(idx, block):
        ls[i] = l
    return "\n".join(ls)


def without_absent_usage(g):
    if "\nSetText|Latency\n" not in g or not ABSENT_ADDONS:
        return g
    sizes = [float(m.group(1)) for m in (USAGE_LINE.match(l) for l in g.split("\n")) if m]
    size = sizes[0] if sizes and all(x == sizes[0] for x in sizes) else None
    assert size is not None, "the stand-in no longer gives every addon the same size: update without_absent_usage"
    out = [l for l in g.split("\n") if not (USAGE_LINE.match(l) and USAGE_LINE.match(l).group(2) in ABSENT_ADDONS)]
    def total(mt):
        return "AddLine|Memory: %.1f MB total|" % (float(mt.group(1)) - size * len(ABSENT_ADDONS))
    return usage_sorted("\n".join(re.sub(r"^AddLine\|Memory: ([0-9.]+) MB total\|", total, l) for l in out))


CONVERTED = ["XayaUI/MinimapButton.lua", "XayaUI_Chat/Privacy.lua", "XayaUI_Chat/History.lua", "XayaUI_Chat/Frame.lua"]


# The Chat clock's hover shows today's date ("Saturday 07 November"): the test runs on any day, so the date text is
# compared as a placeholder; every other call, argument and line is still compared exactly.
DATE_RE = re.compile(r"\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday) \d{1,2} [A-Z][a-z]+\b")


def norm_date(s):
    return DATE_RE.sub("<DATE>", str(s))


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
    logs = sorted(norm_date(res.logs[i]) for i in range(1, len(res.logs) + 1))
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
    want = sorted(norm_date(w) for w in json.load(open(GOLDEN, encoding="utf-8")))
    if not HAS_CHAT:
        chat_want = [w for w in want if is_chat_hover(w)]
        want = [w for w in want if not is_chat_hover(w)]
        check("(XayaUI_Chat absent) exactly the %d hovers XayaUI_Chat draws are left out of the golden" % len(CHAT_HOVERS), len(chat_want) == len(CHAT_HOVERS), len(chat_want))
    if ABSENT_ADDONS:
        want = sorted(without_absent_usage(w) for w in want)
        logs = [usage_sorted(g) for g in logs]
    check("hovers recorded: %d (golden: %d)" % (len(logs), len(want)), len(logs) == len(want))
    missing = [w for w in want if w not in logs]
    extra = [g for g in logs if g not in want]
    check("every hover draws exactly the tooltip it drew before the refactor (same calls, arguments, order)",
          not missing and not extra, "changed/missing: %s || new: %s" % (missing[:2], extra[:2]))
    for label, text in COVERS:
        if not HAS_CHAT and label.startswith("Chat "):
            print("SKIP (QA-branch module absent: XayaUI_Chat) the recording covers %s" % label)
            continue
        check("the recording covers %s" % label, any(text in g for g in logs))
    check("core has the shared tooltip helper ns.Tip (Show, Hide)", tip)
    # DISPLAY-RULES A7.2 (her names everywhere; UI-5 "... to / Data Panels / Data Bars"): the minimap list row (Bonus 0.6.28)
    check("the minimap list names the feature Data Panels (not the old 'Custom data panels')",
          any("SetText|Data Panels|" in g for g in logs) and not any("ustom data panels" in g for g in logs))
    root = os.path.abspath(os.path.join(HERE, ".."))
    for rel in CONVERTED:
        if not HAS_CHAT and rel.startswith("XayaUI_Chat/"):
            print("SKIP (QA-branch module absent: XayaUI_Chat) %s draws its hovers through ns.Tip only (no direct GameTooltip call left)" % rel)
            continue
        code = "\n".join(l.split("--", 1)[0] for l in open(os.path.join(root, rel), encoding="utf-8").read().split("\n"))
        check("%s draws its hovers through ns.Tip only (no direct GameTooltip call left)" % rel, "GameTooltip" not in code)
    for e in errs:
        print("ERROR in the game stand-in:", e)
    check("no Lua errors", not errs, errs[:2])
    print("%d failed" % len(fails))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
