"""docs/reference/build_set_auras.py (the builder of XayaUI/SetBonusAuras.lua) on small made-up tables, written to a temporary folder.
Checks the rules that keep XayaUI from saying "missing" while a set aura is up: an aura linked from several bonuses of its set is "off"
only when all of them are off (fewest pieces, every spec), and an aura anything else can apply is left out.
The IDs below are invented for the test; they are not game data. Run: python3 tests/build_set_auras_run.py (standard library only)."""
import csv, json, os, re, subprocess, sys, tempfile
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

def write(folder, table, header, rows):
    with open(os.path.join(folder, table + ".csv"), "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

with tempfile.TemporaryDirectory() as d:
    # set 900: bonus 9002 (2 pieces, spec 10) and bonus 9004 (4 pieces, spec 20) both trigger aura 9100.
    # set 900: bonus 9006 (2 pieces, any spec) triggers aura 9200, which spell 7000 (not a set bonus) also triggers: not set-only.
    # set 901: bonus 9102 (4 pieces, spec 30) triggers 9110, which triggers aura 9300 (two steps).
    write(d, "ItemSetSpell", ["ID", "ItemSetID", "Threshold", "ChrSpecID", "TraitSubTreeID", "SpellID"],
          [[1, 900, 2, 10, 0, 9002], [2, 900, 4, 20, 0, 9004], [3, 900, 2, 0, 0, 9006], [4, 901, 4, 30, 0, 9102]])
    write(d, "SpellEffect", ["ID", "SpellID", "EffectTriggerSpell", "EffectAura"],
          [[1, 9002, 9100, 0], [2, 9004, 9100, 0], [3, 9100, 0, 4], [4, 9006, 9200, 0], [5, 7000, 9200, 0], [6, 9200, 0, 4],
           [7, 9102, 9110, 0], [8, 9110, 9300, 0], [9, 9300, 0, 4]])
    write(d, "SpellName", ["ID", "Name_lang"], [[9100, "Test Aura A"], [9200, "Test Aura B"], [9300, "Test Aura C"], [9002, "Bonus 2"],
          [9004, "Bonus 4"], [9006, "Bonus any"], [9102, "Bonus C"]])
    write(d, "SkillLineAbility", ["ID", "Spell"], [[1, 7000]])
    write(d, "TraitDefinition", ["ID", "SpellID", "OverridesSpellID", "VisibleSpellID"], [[1, 0, 0, 0]])
    sets = os.path.join(d, "sets.json")
    json.dump({"classes": [{"sets": {"s": [{"setID": 900, "name": "Test Set"}, {"setID": 901, "name": "Test Set C"}]}}]}, open(sets, "w"))
    out = os.path.join(d, "out.lua")
    r = subprocess.run([sys.executable, "-I", os.path.join(ROOT, "docs", "reference", "build_set_auras.py"), "--build", "0.0.0.1",
                        "--cache", d, "--out", out, "--date", "2026-01-01", "--sets", sets], capture_output=True, text=True)
    check("the builder runs on the made-up tables", r.returncode == 0, r.stderr[-400:])
    text = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
    def entry(aura):
        m = re.search(r"\[%d\] = \{ set = (\d+), pieces = (\d+), specs = \{ ([\d, ]+) \}, bonus = (\d+) \}" % aura, text)
        return m and (int(m.group(1)), int(m.group(2)), sorted(int(x) for x in m.group(3).split(",")), int(m.group(4)))
    a = entry(9100)
    check("an aura linked from a 2-piece (spec 10) and a 4-piece (spec 20) bonus: fewest pieces, BOTH specs",
          a == (900, 2, [10, 20], 9002), a)
    check("an aura something outside the set can also apply is left out", entry(9200) is None, entry(9200))
    check("an aura two trigger steps from its bonus is linked", entry(9300) == (901, 4, [30], 9102), entry(9300))
    check("the file says where its facts come from and loads into the namespace",
          "wago.tools" in text and "local _, ns = ..." in text and 'ns.SET_BONUS_BUILD = "0.0.0.1"' in text)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
