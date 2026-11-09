# American spelling in every text the player reads (FA-16 / FA-17, docs/process/REQUEST-LOG.md). Xaya, her words (FA-16):
# "Make sure all UK/CAN/AUS/NZ spellings of words are not reflected into the addon (including words like “favour”). This also
# applies to patch notes, what’s new text — literally every text in the addon should follow American spelling rules / Except use
# the spelling “grey” instead of “gray”". Reported again 2026-11-08: "once again Claude has violated my strict rules around
# english - american spelling" (a tooltip read "Colours your target's health bar ... in the colour set on this page").
#
# Scans (git-tracked files only, V7):
#   - every Lua string literal in XayaUI*/ (Libs excluded; comments stripped, so only text that can reach the screen is read)
#   - the .toc "## Title" / "## Notes" lines (the AddOns list)
#   - the text files shipped inside the addon folders (README / CREDITS / walkthrough .md / .txt, the media script), except the
#     third-party font and sound licences (OFL-*.txt, LICENSE-*.txt: other people's legal text)
#   - PATCH-NOTES.md, docs/WHATS-NEW.md, docs/USER-GUIDE.md, docs/HELP-FAQ.md, docs/README-INGAME.md and docs/QA-CHECKLIST.md
# for the British / Commonwealth spellings below (whole words, any case, every inflection; camelCase and snake_case parts count as
# words, so "ShownColour" and "STATUS_COLOUR" are found too). Her exception: "grey" is the spelling to use, so "gray" (and its
# inflections) is a hit and "grey" is not. A hit is allowed only by an entry in ALLOW below, and each entry says why the string must
# not change (a saved-data key, a file / function / API name, a slash-command alias, the audit's own search list, her own quoted
# words). An ALLOW entry that no longer matches anything is also a failure, so the list cannot go stale.
# Run from the repo root: python3 tests/american_spelling_run.py   (no Lua needed)
import os, re, subprocess, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DOCS = ["PATCH-NOTES.md", "docs/WHATS-NEW.md", "docs/USER-GUIDE.md", "docs/HELP-FAQ.md", "docs/README-INGAME.md",
        "docs/QA-CHECKLIST.md"]

# --- the word list --------------------------------------------------------------------------------------------------------------
# Each pattern is matched against one whole word (lower-cased). "\w*" before / after an -our stem: "colour" inside any word is
# British ("recoloured", "multicolour", "colourful"), and no American word contains these stems.
OUR = ["colour", "favour", "behaviour", "honour", "armour", "neighbour", "rumour", "labour", "humour", "flavour", "harbour", "vapour",
       "savour", "endeavour", "odour", "vigour", "rigour", "splendour", "parlour", "clamour", "valour", "candour", "ardour", "fervour",
       "saviour", "tumour"]   # "glamour" is also the usual American spelling
RE_WORDS = [
    r"\w*(?:%s)\w*" % "|".join(OUR),
    # -re
    r"(?:epi)?centre(?:s|d)?|centring",
    r"\w*metre(?:s)?|litre(?:s)?|fibre(?:s|glass)?|theatre(?:s)?|calibre(?:s)?|sombre(?:ly)?|lustre|spectre(?:s)?|sabre(?:s)?",
    r"meagre|manoeuvre(?:s|d)?|manoeuvring|ochre",
    # -ogue (American: catalog, analog, dialog); "prologue" / "monologue" are the American spellings too, so they are not listed
    r"catalogue(?:s|d)?|cataloguing|analogue(?:s)?|dialogue(?:s)?",
    # -ence
    r"licence(?:s|d)?|defence(?:s|less)?|offence(?:s)?|pretence(?:s)?",
    r"practis(?:e|ed|es|ing)",
    # -ise / -isation verbs (American: -ize). Listed stems only: advise, devise, exercise, promise, raise, revise, surprise ... are
    # American with -ise.
    r"(?:un|re|de|dis|over|under|pre)?(?:compartmental|commercial|conceptual|contextual|individual|anaesthet|character|"
    r"parameter|philosoph|spiritual|anesthet|cannibal|familiar|hospital|immortal|internal|marginal|miniatur|national|parallel|"
    r"personal|proselyt|rational|standard|synchron|systemat|tranquil|antagon|capital|categor|central|channel|crystal|desatur|"
    r"fratern|general|homogen|initial|jeopard|journal|legitim|liberal|literal|militar|natural|neutral|pasteur|plagiar|politic|"
    r"polymer|popular|pressur|priorit|prophes|radical|regular|rhapsod|scandal|scrutin|secular|special|stigmat|symmetr|sympath|"
    r"synthes|templat|trivial|virtual|weather|western|actual|annual|apolog|author|carbon|catech|cauter|colour|critic|custom|"
    r"deodor|dramat|econom|empath|emphas|euthan|factor|fantas|fertil|formal|fossil|galvan|global|harmon|hypnot|italic|magnet|"
    r"mesmer|modern|mutual|normal|ostrac|patron|plural|pulver|random|raster|recogn|sensit|serial|sermon|sexual|social|solemn|"
    r"stabil|steril|subsid|summar|syllab|symbol|tender|terror|tyrann|vandal|vector|victim|visual|winter|canon|civil|colon|demon|"
    r"digit|energ|equal|final|focal|human|ideal|immun|legal|local|maxim|memor|metal|minim|mobil|monet|moral|motor|optim|organ|"
    r"penal|polar|quant|sanit|satir|theor|token|total|urban|vapor|vital|vocal|agon|atom|bapt|idol|item|lion|oxid|real|styl|util)"
    r"is(?:e|ed|es|ing|er|ers|ation|ations|able)",
    r"(?:re|de)?(?:anal|paral|catal|hydrol|dial|electrol)ys(?:e|ed|ing|er|ers)",   # "analyses" is also the American plural noun
    # -ll- inflections (American: one l)
    r"(?:re|un|mis)?(?:label|cancel|travel|model|level|signal|fuel|total|channel|dial|marvel|counsel|equal|tunnel|funnel|rival"
    r"|panel|pencil|quarrel|shovel|swivel|ravel|unravel|gravel|duel|jewel|libel|snorkel|yodel|grovel|spiral|initial)"
    r"(?:led|ling|ler|lers)",
    r"counsellor(?:s)?|marvellous(?:ly)?|jewellery|woollen(?:s)?",
    # -l / -ment
    r"enrol(?:s|ment|ments)?|fulfil(?:s|ment|ments)?|instil(?:s)?|instalment(?:s)?|skilful(?:ly|ness)?|wilful(?:ly|ness)?",
    r"focuss(?:ed|es|ing)|benefitt(?:ed|ing)",
    # irregular past tenses (American: learned, spelled, ...)
    r"learnt|spelt|dreamt|spoilt|leant|spilt|burnt",
    r"judgement(?:s|al)?|acknowledgement(?:s)?|ageing|whilst|amongst|amidst",
    r"programme(?:s|d)?|cheque(?:s)?|tyre(?:s)?|alumini?um|plough(?:s|ed|ing)?|sceptic(?:s|al|ally|ism)?|artefact(?:s)?",
    r"mould(?:s|ed|ing|y)?|smoulder(?:s|ed|ing)?|moult(?:s|ed|ing)?|kerb(?:s)?|pyjamas|aeroplane(?:s)?|anticlockwise|maths",
    r"cos(?:y|ier|iest|ily)|gramme(?:s)?|tonne(?:s)?|speciality|specialities|storey(?:s)?|draught(?:s|y)?|queueing",
    r"orientat(?:e|ed|es|ing)|enquir(?:e|ed|es|ing|y|ies)|sulphur\w*|despatch(?:ed|es|ing)?|moustache(?:s)?|disc(?:s)?",
    # her exception: "grey", never "gray"
    r"(?:un)?gray(?:s|ed|ing|ish|ness|scale)?|grayscale",
]
WORD_RX = re.compile(r"^(?:%s)$" % "|".join("(?:%s)" % p for p in RE_WORDS))
PHRASE_RX = re.compile(r"\bper cent\b", re.I)

# --- the allow-list: strings that must NOT change -------------------------------------------------------------------------------
# A hit is allowed when the path matches, the word matches (None = any word) and the context is found in the string itself (or, for
# a context starting "line:", on the string's source line). Each entry says why the string must stay as it is.
ALLOW = [
    # (none at present: every hit in XayaUI, XayaUI_Options and XayaUI_Rules, the editor included, is respelled. The entries
    # that used to be here all allowed strings of addons that are no longer on this branch.)
]
# Table fields whose strings are her own words, verbatim, and are never respelled: (path, field, why). None at present.
ALLOW_FIELDS = []

# --- reading the sources --------------------------------------------------------------------------------------------------------
def tracked():
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout
    return [l for l in out.splitlines() if l]

def lua_strings(src):
    """Every string literal in a Lua source (comments skipped): (line, text, start, end, prefix). text has the escapes decoded;
    src[start:end] is the raw literal body; prefix is the code before it on its line."""
    out, i, n, line = [], 0, len(src), 1
    def long_open(j):
        if j < n and src[j] == "[":
            k = j + 1
            while k < n and src[k] == "=": k += 1
            if k < n and src[k] == "[": return k - j - 1, k + 1
        return None, None
    def prefix(at): return src[src.rfind("\n", 0, at) + 1:at]
    while i < n:
        c = src[i]
        if c == "\n": line += 1; i += 1; continue
        if src.startswith("--", i):
            lvl, body = long_open(i + 2)
            if lvl is not None:
                end = src.find("]" + "=" * lvl + "]", body)
                end = n if end < 0 else end + lvl + 2
                line += src.count("\n", i, end); i = end
            else:
                end = src.find("\n", i); i = n if end < 0 else end
            continue
        if c == "[":
            lvl, body = long_open(i)
            if lvl is not None:
                end = src.find("]" + "=" * lvl + "]", body)
                end = n if end < 0 else end
                out.append((line, src[body:end], body, end, prefix(i))); line += src.count("\n", i, end); i = end + lvl + 2
                continue
        if c in "\"'":
            j, buf = i + 1, []
            while j < n and src[j] != c:
                if src[j] == "\\" and j + 1 < n:
                    e = src[j + 1]
                    buf.append({"n": " ", "t": " ", "r": " ", "\\": "\\", '"': '"', "'": "'"}.get(e, " " if e in "z\n" else e))
                    if e == "\n": line += 1
                    j += 2; continue
                if src[j] == "\n": break   # broken string; stop at the line end
                buf.append(src[j]); j += 1
            out.append((line, "".join(buf), i + 1, j, prefix(i))); i = j + 1
            continue
        i += 1
    return out

ESC_RX = re.compile(r"\|c(?:[0-9a-fA-F]{8}|n[A-Za-z0-9_]+:)|\|[rn]|\|T[^|]*\|t|\|H[^|]*\|h|\|A[^|]*\|a")
def word_spans(text):
    """(start, end, word) of every word: letters only, camelCase and snake_case parts split, WoW escape codes skipped."""
    masked = ESC_RX.sub(lambda m: " " * len(m.group(0)), text)
    for tok in re.finditer(r"[A-Za-z]+", masked):
        for w in re.finditer(r"[A-Z]+(?![a-z])|[A-Z]?[a-z]+", tok.group(0)):
            yield tok.start() + w.start(), tok.start() + w.end(), w.group(0)

def hits_in(text):
    found = [w.lower() for _, _, w in word_spans(text) if WORD_RX.match(w.lower())]
    found += [m.group(0).lower() for m in PHRASE_RX.finditer(text)]
    return found

def sources():
    """Every text to check, as dicts: path, line, text, kind, srcline (its whole source line), field (Lua: the table field the
    string is the value of, if any) and, for Lua strings, start / end (the raw literal body's offsets in the file)."""
    files = tracked()
    for p in files:
        top = p.split("/", 1)[0]
        if not top.startswith("XayaUI") or "/Libs/" in p: continue
        full = os.path.join(ROOT, p)
        base = os.path.basename(p)
        if p.endswith(".lua"):
            src = open(full, encoding="utf-8", errors="replace").read()
            lines = src.split("\n")
            for ln, s, a, b, pre in lua_strings(src):
                f = re.search(r"\b([A-Za-z_]\w*)\s*=\s*$", pre)
                yield dict(path=p, line=ln, text=s, kind="lua string", srcline=lines[ln - 1], field=f and f.group(1), start=a, end=b)
        elif p.endswith(".toc"):
            for ln, l in enumerate(open(full, encoding="utf-8", errors="replace"), 1):
                if re.match(r"##\s*(Title|Notes)\b", l):
                    yield dict(path=p, line=ln, text=l.rstrip("\n"), kind="toc", srcline=l, field=None)
        elif p.endswith((".md", ".txt", ".py")) and not base.startswith(("OFL-", "LICENSE")):
            for ln, l in enumerate(open(full, encoding="utf-8", errors="replace"), 1):
                yield dict(path=p, line=ln, text=l.rstrip("\n"), kind="addon text file", srcline=l, field=None)
    for p in DOCS:
        if p not in files: continue
        for ln, l in enumerate(open(os.path.join(ROOT, p), encoding="utf-8", errors="replace"), 1):
            yield dict(path=p, line=ln, text=l.rstrip("\n"), kind="doc", srcline=l, field=None)

def allowed(src, w, used=None):
    for ap, field, _why in ALLOW_FIELDS:
        if ap == src["path"] and src["field"] == field: return True
    for k, (ap, aw, ctx, _why) in enumerate(ALLOW):
        if ap == src["path"] and (aw is None or aw == w) and (ctx[5:] in src["srcline"] if ctx.startswith("line:") else ctx in src["text"]):
            if used is not None: used.add(k)
            return True
    return False

def main():
    fails = []
    # self-test of the matcher and the Lua reader, so a broken pattern cannot pass silently
    for w in ["colour", "Colours", "recoloured", "ShownColour", "STATUS_COLOUR", "favourite", "behaviour", "centred", "kilometre",
              "catalogue", "AuraCatalogue", "organisation", "customise", "initialised", "analyse", "labelled", "cancelling", "fulfil",
              "learnt", "acknowledgements", "gray", "Grays", "ungrayed", "whilst", "licence", "defence", "programme", "per cent",
              "|cffffd100Colour|r", "|cff88ccffcolour"]:
        if not hits_in(w): fails.append("matcher misses %r" % w)
    for w in ["color", "colored", "favorite", "behavior", "centered", "catalog", "organization", "customize", "analyze", "analyses",
              "labeled", "canceled", "cancellation", "fulfill", "learned", "acknowledgments", "grey", "Greys", "ungreyed", "greyish",
              "advise", "exercise", "promise", "surprised", "raise", "revised", "license", "defense", "program", "Discipline",
              "prologue", "monologue", "|cffff0000Red|r", "controlled", "Paradise", "precise", "Noise", "percent", "specialist"]:
        if hits_in(w): fails.append("matcher flags the American / allowed %r: %s" % (w, hits_in(w)))
    if [s for _, s, _, _, _ in lua_strings('local a = "x" -- "colour"\n--[[ "colour" ]] b = [[y]] c = \'z\'')] != ["x", "y", "z"]:
        fails.append("the Lua reader does not skip comments")

    used, hits, n_texts = set(), [], 0
    for src in sources():
        n_texts += 1
        for w in hits_in(src["text"]):
            if not allowed(src, w, used): hits.append((src["path"], src["line"], w, src["kind"], src["text"].strip()))
    for k, (ap, aw, ctx, why) in enumerate(ALLOW):
        if k not in used: fails.append("ALLOW entry matches nothing (remove it): %s %r %r (%s)" % (ap, aw, ctx, why))

    by_file = {}
    for path, ln, w, kind, text in hits:
        by_file[path] = by_file.get(path, 0) + 1
        print("FAIL %s:%d [%s] %s   in: %s" % (path, ln, kind, w, text[:110]))
    for f in fails: print("FAIL " + f)
    if hits:
        print("British / Commonwealth spellings by file:")
        for p in sorted(by_file, key=lambda p: -by_file[p]): print("  %4d  %s" % (by_file[p], p))
    total = len(hits) + len(fails)
    print("%d texts checked, %d British spellings, %d other problems  FAILS: %d" % (n_texts, len(hits), len(fails), total))
    return 1 if total else 0

if __name__ == "__main__":
    sys.exit(main())
