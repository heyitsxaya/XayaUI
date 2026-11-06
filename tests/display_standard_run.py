#!/usr/bin/env python3
"""The display standard in code (core 0.6.59, Options 0.6.60; REQUEST-LOG UI-47, Xaya 2026-11-06: "review every single tab within the
entire addon and make sure every single display type is correctly standardized. make sure all design and addon display rules are
stored in their own file in the appropriate location if they aren't already. / refactor all code appropriately."; the rules:
docs/design/DISPLAY-RULES.md, her words: docs/design/DISPLAY-RULINGS.md).
Checks, on the real addons in the stand-in game (options tree only, nothing drawn):
  1 core ns.Style holds every value of DISPLAY-RULES.md section C, with the values written there (the file is read here, so the two
    cannot drift apart);
  2 her answer for text inputs (UI-48, "Half width, two per row"): every one-line text input in every tab is half the row unless the
    module gave it a narrower width; multi-line boxes stay full; none is left stretching the row;
  3 every left-pane switch (xuiSwitch) in every feature tab has a one-sentence hover text without "Off" (UI-42).
Negative control: on main 687b624 (core 0.6.57) checks 1 to 3 fail (no ns.Style, full-row inputs, no hover sentences).
Run: python3 tests/display_standard_run.py   (Lua 5.1 via lupa)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

ROOT = os.path.abspath(os.path.join(HERE, ".."))


def section_c():
    """The value rows of DISPLAY-RULES.md section C, as (key path, list of numbers or a word)."""
    text = open(os.path.join(ROOT, "docs", "design", "DISPLAY-RULES.md"), encoding="utf-8").read()
    part = text.split("## C.", 1)[1]
    rows = []
    for line in part.splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3 or cells[0] in ("Key", "---") or set(cells[0]) <= set("-"):
            continue
        rows.append((cells[0], cells[1]))
    return rows


LUA = r'''
return function(W, L, want)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
-- 1 ns.Style against section C
local S = ns and ns.Style
check("1: core ns.Style exists", type(S) == "table")
S = S or {}
local function get(path) local v = S; for k in path:gmatch("[^%.]+") do v = type(v) == "table" and v[tonumber(k) or k] or nil end return v end
for i = 1, #want do
  local key, nums = want[i][1], want[i][2]
  local ok, why = true, ""
  for j = 1, #nums do
    local k, n = nums[j][1], nums[j][2]
    local v = get(k)
    if type(n) == "number" then if v ~= n then ok = false; why = why .. k .. "=" .. tostring(v) .. " " end
    elseif type(n) == "boolean" then if v ~= n then ok = false; why = why .. k .. "=" .. tostring(v) .. " " end
    elseif n == "half" then if v ~= "half" then ok = false; why = why .. k .. "=" .. tostring(v) .. " " end end
  end
  check("1: ns.Style has " .. key .. " as written in DISPLAY-RULES.md section C", ok, why)
end
check("1: the old names read the same values (ns.UI_MARGIN, ns.UI_GUTTER)", ns.UI_MARGIN == S.margin and ns.UI_GUTTER == S.gutter)
-- 2 inputs
local T = ns.BuildOptionsTable and ns.BuildOptionsTable()
check("2: the options tree builds", type(T) == "table")
local bad, n = {}, 0
local function walk(g, path, depth)
  if type(g) ~= "table" or depth > 14 then return end
  for k, o in pairs(type(g.args) == "table" and g.args or {}) do
    if type(o) == "table" then
      if o.type == "input" and not o.multiline and not o.dialogControl then
        n = n + 1
        if o.width == nil or o.width == "full" or o.width == "double" or (o.width == "relative" and (tonumber(o.relWidth) or 1) > 0.5) then
          bad[#bad + 1] = path .. ">" .. tostring(k)
        end
      elseif o.type == "group" then walk(o, path .. ">" .. tostring(k), depth + 1) end
    end
  end
end
walk(T, "", 0)
check("2: every one-line text input is at most half the row (" .. n .. " inputs)", n > 0 and #bad == 0, table.concat(bad, ", "):sub(1, 400))
-- 3 hover sentences
local miss, sw = {}, 0
local function sws(g, path, depth)
  if type(g) ~= "table" or depth > 14 then return end
  if type(g.xuiSwitch) == "table" then
    sw = sw + 1
    local t = g.xuiSwitch.tip
    if not (type(t) == "string" and t ~= "" and t:match("[%.!?]$") and not t:sub(1, -2):find("[%.!?]%s") and not t:find("Off")) then
      miss[#miss + 1] = path .. "=" .. tostring(t)
    end
  end
  for k, o in pairs(type(g.args) == "table" and g.args or {}) do
    if type(o) == "table" and o.type == "group" then sws(o, path .. ">" .. tostring(k), depth + 1) end
  end
end
for _, tab in ipairs({ "qol", "bonus", "chat", "reskin" }) do sws(T and T.args and T.args[tab], tab, 0) end
check("3: every left-pane switch has a one-sentence hover without \"Off\" (" .. sw .. " switches)", sw > 0 and #miss == 0, table.concat(miss, " | "):sub(1, 400))
return R
end
'''


def parse_want():
    """Section C rows -> [(label, [(ns.Style path, value)])]. Only rows whose key names an ns.Style field are checked."""
    out = []
    for key, val in section_c():
        keys = [k.strip() for k in re.sub(r"\(.*?\)", "", key).split(",")]
        vals = [v.strip() for v in re.sub(r"\(.*?\)", "", val).split(",")]
        pairs = []
        if key.startswith("margin"):
            pairs = [("margin", float(vals[0])), ("gutter", float(vals[1]))]
        elif key.startswith("tab"):
            for k, v in zip(keys, vals):
                pairs.append((k, True if v == "true" else float(v)))
        elif key.startswith("nest.child"):
            pairs = [("nest.child", float(vals[0]))]
        elif key.startswith("nest.level"):
            pairs = [("nest.level", float(vals[0]))]
        elif key.startswith("switch.size"):
            pairs = [("switch.size", float(vals[0]))]
        elif key.startswith("grey"):
            pairs = [("grey.1", float(vals[0])), ("grey.2", float(vals[1])), ("grey.3", float(vals[2]))]
        elif key.startswith("divider"):
            pairs = [("divider.size", float(re.match(r"(\d+)", vals[0]).group(1)))]
        elif key.startswith("bodyIndent"):
            pairs = [("bodyIndent", float(vals[0]))]
        elif key.startswith("input.width"):
            pairs = [("input.width", "half")]
        if pairs:
            out.append((key, pairs))
    return out


def main():
    want = parse_want()
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    lw = L.table_from([L.table_from([k, L.table_from([L.table_from([p, v]) for p, v in pairs])]) for k, pairs in want])
    res = L.eval("function(src, W, Ld, w) return loadstring(src)()(W, Ld, w) end")(LUA, world, loader, lw)
    bad = 0
    print("section C rows read: %d" % len(want))
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    if len(want) < 10:
        print("FAIL section C of DISPLAY-RULES.md: fewer value rows than the 10 written there (%d)" % len(want))
        bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
