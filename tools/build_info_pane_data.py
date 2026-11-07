#!/usr/bin/env python3
"""Build XayaUI_Options/InfoPaneData.lua from the markdown the version pane shows (the game cannot read repository files).

Sources:
  PATCH-NOTES.md            Patch Notes: one left-side entry per landing (## date — title), plus What's New built from it
  docs/README-INGAME.md     Info > Readme
  docs/HELP-FAQ.md          Info > Help (FAQ)

What's New (Xaya 2026-11-06: "emphasizes only new features"; "minor updates over the course of a few days across incremental
rather than MAJOR version updates get displayed e.g. 0.7.x vs 0.8.0"; "append incremental updates to the top of the list as they
come in"): every bullet of a "**Name (new)**" category and every top-level bullet that starts with "Added", newest first, grouped by
addon, for the addon's current x.Y line only (its newest version in PATCH-NOTES.md). An addon's list starts again at x.Y+1.0.

Usage:
  python3 tools/build_info_pane_data.py           rewrite the Lua file
  python3 tools/build_info_pane_data.py --check   exit 1 if the Lua file is not what the sources give (tests/info_pane_run.py)
"""
import os, re, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC_PATCH = os.path.join(ROOT, "PATCH-NOTES.md")
SRC_README = os.path.join(ROOT, "docs", "README-INGAME.md")
SRC_FAQ = os.path.join(ROOT, "docs", "HELP-FAQ.md")
OUT = os.path.join(ROOT, "XayaUI_Options", "InfoPaneData.lua")

ADDONS = ["XayaUI", "Options", "Chat", "Quality of Life", "Bonus Features", "Blizzard Reskin", "Dev Assist", "Media"]
DASH = "\u2014"


class SourceError(Exception):
    pass


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def esc_pipes(s):
    # the game reads "|" as the start of an escape sequence; "||" shows one "|"
    return s.replace("|", "||")


def parse_blocks(lines, where):
    """Markdown subset -> blocks: ("h1"|"h2"|"h3", text) ("grp", text) ("p", text) ("b", level, text) ("dev", level, text)."""
    blocks, para = [], []

    def flush():
        if para:
            blocks.append(("p", esc_pipes(" ".join(para))))
            para.clear()

    for n, raw in enumerate(lines, 1):
        line = raw.rstrip()
        if not line.strip():
            flush()
            continue
        m = re.match(r"^(#{1,3})\s+(.*)$", line)
        if m:
            flush()
            blocks.append(("h%d" % len(m.group(1)), esc_pipes(m.group(2).strip())))
            continue
        m = re.match(r"^( *)- (.*)$", line)
        if m:
            flush()
            indent = len(m.group(1))
            if indent % 2:
                raise SourceError("%s line %d: a nested bullet is indented by two spaces per level" % (where, n))
            blocks.append(("b", indent // 2 + 1, esc_pipes(m.group(2).strip())))
            continue
        m = re.match(r"^( *)\*(Developers' notes?:.*)\*\s*$", line)
        if m:
            flush()
            blocks.append(("dev", len(m.group(1)) // 2 + 1, esc_pipes(m.group(2).strip())))
            continue
        m = re.match(r"^\*\*(.+)\*\*\s*$", line)
        if m:
            flush()
            blocks.append(("grp", esc_pipes(m.group(1).strip())))
            continue
        if line.startswith("  ") and blocks and blocks[-1][0] in ("b", "dev") and not para:
            # a wrapped bullet line continues the bullet
            k = blocks[-1]
            blocks[-1] = k[:-1] + (k[-1] + " " + esc_pipes(line.strip()),)
            continue
        para.append(line.strip())
    flush()
    return blocks


def read(path):
    if not os.path.exists(path):
        raise SourceError("missing source file: " + os.path.relpath(path, ROOT))
    with open(path, encoding="utf-8") as f:
        return strip_comments(f.read())


def drop_title(blocks):
    return blocks[1:] if blocks and blocks[0][0] == "h1" else blocks


def vkey(v):
    return tuple(int(x) for x in v.split("."))


def parse_patch_notes(text):
    """-> list of landings {date, title, blocks, sections: [{addon, version, items: [(feature, [blocks])]}]}"""
    lines = text.split("\n")
    landings, cur = [], None
    starts = []
    for i, line in enumerate(lines):
        m = re.match(r"^##\s+(\d{4}-\d{2}-\d{2})\s+" + DASH + r"\s+(.+?)\s*$", line)
        if m:
            starts.append((i, m.group(1), m.group(2)))
        elif re.match(r"^##\s", line):
            raise SourceError("PATCH-NOTES.md line %d: a landing heading reads '## YYYY-MM-DD %s Title'" % (i + 1, DASH))
    if not starts:
        raise SourceError("PATCH-NOTES.md has no landing ('## YYYY-MM-DD %s Title')" % DASH)
    for k, (i, date, title) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        blocks = parse_blocks(lines[i + 1:end], "PATCH-NOTES.md (%s)" % date)
        sections, sec, grp = [], None, None
        for b in blocks:
            if b[0] == "h3":
                m = re.match(r"^(.+?)\s+(\d+\.\d+\.\d+)$", b[1])
                if not m or m.group(1) not in ADDONS:
                    raise SourceError("PATCH-NOTES.md (%s): '### %s' must be '### <addon> <x.y.z>', addon one of %s"
                                      % (date, b[1], ", ".join(ADDONS)))
                sec = {"addon": m.group(1), "version": m.group(2), "items": []}
                sections.append(sec)
                grp = None
            elif b[0] in ("h1", "h2"):
                raise SourceError("PATCH-NOTES.md (%s): only ### headings inside a landing" % date)
            elif sec is None:
                raise SourceError("PATCH-NOTES.md (%s): text before the first '### <addon> <version>'" % date)
            elif b[0] == "grp":
                grp = b[1]
            elif b[0] == "b" and b[1] == 1:
                if grp is None:
                    raise SourceError("PATCH-NOTES.md (%s, %s %s): a bullet before any **Feature** line"
                                      % (date, sec["addon"], sec["version"]))
                sec["items"].append([grp, [b]])
            elif b[0] in ("b", "dev"):
                if not sec["items"]:
                    raise SourceError("PATCH-NOTES.md (%s): a nested bullet or note with no bullet above it" % date)
                sec["items"][-1][1].append(b)
        landings.append({"date": date, "title": esc_pipes(title), "blocks": blocks, "sections": sections})
    dates = [l["date"] for l in landings]
    if dates != sorted(dates, reverse=True):
        raise SourceError("PATCH-NOTES.md: landings must be newest first (%s)" % ", ".join(dates))
    return landings


def is_new(feature, first_bullet):
    return feature.endswith("(new)") or first_bullet[2].startswith("Added")


def whats_new(landings):
    newest = {}
    for l in landings:
        for s in l["sections"]:
            if s["addon"] not in newest or vkey(s["version"]) > vkey(newest[s["addon"]]):
                newest[s["addon"]] = s["version"]
    per_addon, order = {}, []
    for l in landings:   # newest landing first; inside a landing, the file's order (newest version first)
        for s in l["sections"]:
            line = newest[s["addon"]].rsplit(".", 1)[0]
            if s["version"].rsplit(".", 1)[0] != line:
                continue   # an older x.Y line of this addon
            for feature, bl in s["items"]:
                if not is_new(feature, bl[0]):
                    continue
                if s["addon"] not in per_addon:
                    per_addon[s["addon"]] = []
                    order.append(s["addon"])
                per_addon[s["addon"]].append((feature, s["version"], l["date"], bl))
    out = []
    for addon in order:
        out.append(("h3", "%s %s.x" % (addon, newest[addon].rsplit(".", 1)[0])))
        last = None
        for feature, version, date, bl in per_addon[addon]:
            name = re.sub(r"\s*\(new\)$", "", feature)
            head = "%s  (%s, %s)" % (name, version, date)
            if head != last:
                out.append(("grp", head))
                last = head
            out.extend(bl)
    return out


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lua_blocks(blocks, ind):
    rows = []
    for b in blocks:
        rows.append(ind + "{ " + ", ".join(lua_str(x) if isinstance(x, str) else str(x) for x in b) + " },")
    return "\n".join(rows)


def build():
    landings = parse_patch_notes(read(SRC_PATCH))
    readme = drop_title(parse_blocks(read(SRC_README).split("\n"), "docs/README-INGAME.md"))
    faq = drop_title(parse_blocks(read(SRC_FAQ).split("\n"), "docs/HELP-FAQ.md"))
    wn = whats_new(landings)
    out = []
    out.append("-- GENERATED by tools/build_info_pane_data.py from PATCH-NOTES.md, docs/README-INGAME.md and docs/HELP-FAQ.md.")
    out.append("-- Do not edit: edit the markdown and run the tool. tests/info_pane_run.py fails when this file and the markdown differ.")
    out.append("-- Loaded with XayaUI_Options (load on demand), so it costs nothing until the settings window is first opened.")
    out.append("-- Blocks: { kind, ... }  h2/h3/grp/p = { kind, text }; b/dev = { kind, level, text }. Inline **bold** and `code` are")
    out.append("-- coloured by InfoPane.lua; a \"|\" is already doubled for the game.")
    out.append("local _, ns = ...")
    out.append("ns = _G.XayaUI_NS or ns")
    out.append("ns.InfoPaneData = {")
    out.append("  whatsNew = {")
    out.append(lua_blocks(wn, "    "))
    out.append("  },")
    out.append("  patches = {")
    for l in landings:
        out.append("    { date = %s, title = %s, blocks = {" % (lua_str(l["date"]), lua_str(l["title"])))
        out.append(lua_blocks(l["blocks"], "      "))
        out.append("    } },")
    out.append("  },")
    out.append("  readme = {")
    out.append(lua_blocks(readme, "    "))
    out.append("  },")
    out.append("  faq = {")
    out.append(lua_blocks(faq, "    "))
    out.append("  },")
    out.append("}")
    return "\n".join(out) + "\n"


def main():
    try:
        text = build()
    except SourceError as e:
        print("build_info_pane_data: " + str(e))
        sys.exit(2)
    if "--check" in sys.argv[1:]:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            print("XayaUI_Options/InfoPaneData.lua is out of date: run python3 tools/build_info_pane_data.py")
            sys.exit(1)
        print("XayaUI_Options/InfoPaneData.lua matches its markdown sources")
        return
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote %s (%d bytes)" % (os.path.relpath(OUT, ROOT), len(text.encode("utf-8"))))


if __name__ == "__main__":
    main()
