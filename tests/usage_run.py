# Checks B.UsageLines / B.AddUsage (DataBlocks.lua) against stand-in addon profiler + memory APIs, and that the edited files compile.
import os
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lua51 as lupa   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
L = lupa.runtime(unpack_returned_tuples=True)
HAS_CHAT = os.path.isdir(os.path.join(ROOT, 'XayaUI_Chat'))
LIB_REL = 'XayaUI_Chat/Libs/XayaDataBlocks-1.0/XayaDataBlocks-1.0.lua'
if not HAS_CHAT:
    LIB_REL = 'XayaUI_Bonus/Libs/XayaDataBlocks-1.0/XayaDataBlocks-1.0.lua'  # identical copy shipped with Bonus
for f in ('XayaUI_Chat/Libs/XayaDataBlocks-1.0/XayaDataBlocks-1.0.lua', 'XayaUI_Chat/Bar.lua', 'XayaUI_Bonus/DataPanels.lua') + (() if HAS_CHAT else (LIB_REL,)):
    if not os.path.isfile(os.path.join(ROOT, f)):
        print('SKIP (QA-branch module absent: XayaUI_Chat) compiles: ' + f)
        continue
    src = open(os.path.join(ROOT, f), encoding='utf-8').read()
    res = L.eval('function(s, n) local f, e = load(s, n); if f then return "ok" end return e end')(src, '@' + f)
    assert res == 'ok', f"{f} does not compile: {res}"
    print('compiles:', f)
L.globals().DATA_SRC = open(os.path.join(ROOT, LIB_REL), encoding='utf-8').read()
L.globals().LIBSTUB_SRC = open(os.path.join(ROOT, 'XayaUI', 'Libs', 'LibStub', 'LibStub.lua'), encoding='utf-8').read()
L.execute(open(os.path.join(ROOT, 'tests', 'usage_check.lua'), encoding='utf-8').read())
