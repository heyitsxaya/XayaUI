# Checks B.UsageLines / B.AddUsage (DataBlocks.lua) against stand-in addon profiler + memory APIs, and that the edited files compile.
import lupa, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
L = lupa.LuaRuntime(unpack_returned_tuples=True)
for f in ('DataBlocks.lua', 'Chat/Bar.lua', 'DataPanels.lua'):
    src = open(os.path.join(ROOT, f), encoding='utf-8').read()
    res = L.eval('function(s, n) local f, e = load(s, n); if f then return "ok" end return e end')(src, '@' + f)
    assert res == 'ok', f"{f} does not compile: {res}"
    print('compiles:', f)
L.globals().DATA_SRC = open(os.path.join(ROOT, 'DataBlocks.lua'), encoding='utf-8').read()
L.execute(open(os.path.join(ROOT, 'tests', 'usage_check.lua'), encoding='utf-8').read())
