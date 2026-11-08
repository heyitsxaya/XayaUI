-------------------------------------------------------------------------------
-- QAWalks-debug-w7.lua (XayaUI_DevAssist 0.7.66): in-game QA walkthrough for debug batch W7 (QA step B293, #467).
--   #467 a click that changes a rule in the rule editor took 136 to 221 ms in her J31 runs (2026-11-07: "82 ms build and draw + 54 ms
--   skin", "129 + 92"). The stand-in profile (tests/rule_click_cost_run.py, 313 rules) found the skin pass's minimum-width scan
--   (Options Skin.lua ScanDropdowns) measuring every option text of every dropdown in the tree again on each such click: 13,054 texts,
--   26,102 game calls, about half of all the game calls of the click. Options 0.6.100 keeps the widths it measured (dropped when the
--   measuring font changes); the answer is the same (tests/rule_click_cost_run.py C).
-- Standing rule V22 (Xaya 2026-11-07): the step the addon can judge offers its verdict (prefill = true; recorded only on her click):
-- on a repeat click the scan measured no text anew. What it reads (each rule-editor redraw's ms, split as build and draw + skin, and
-- the scan's counts) goes into the note, to compare with her J31 numbers above. The ms are the window's own timing (Options.lua's
-- wrap of AceConfigDialog:Open, the same numbers J31 reads). Uses J31's redraw record (QAWalks-perf.lua). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

-- the last `n` redraws that built the open rule's editor, newest first
local function RuleRedraws(n)
    local key = QA.PerfOnScreenRule and QA.PerfOnScreenRule()
    local out = {}
    for i = #(QA.PerfRedraws or {}), 1, -1 do
        local r = QA.PerfRedraws[i]
        if r.rule == key and r.built then out[#out + 1] = r; if #out >= n then break end end
    end
    return key, out
end
local function Check()
    if not (QA.PerfWatchRedraws and QA.PerfWatchRedraws()) then return nil, "the settings window is not loaded: press Do it for me" end
    local key, list = RuleRedraws(4)
    if not key then return nil, "no rule is selected in the sidebar: click a rule first" end
    if #list < 2 then return nil, ("%d rule-editor redraw(s) measured for %s so far: click a switch in its editor on, then off, then Check again"):format(#list, key) end
    if list[1].scans == nil then return false, "the settings window does not report its width scan (XayaUI Options older than 0.6.100?)" end
    local parts = {}
    for i = #list, 1, -1 do
        local r = list[i]
        parts[#parts + 1] = ("#%d %.0f ms (%.0f build and draw + %.0f skin; width scan: %s of %s texts measured anew)"):format(r.n, r.build + r.skin, r.build, r.skin,
            tostring(r.measured or "?"), tostring(r.texts or "?"))
    end
    local last = list[1]
    local ok = last.measured == 0
    return ok, ("%s, last %d click redraws: %s. Before (J31, 2026-11-07): 136 ms (82 + 54 skin) and 221 ms (129 + 92 skin)%s"):format(key, #list,
        table.concat(parts, "; "), ok and "" or ": the last scan measured texts again (expected 0 on a repeat click)")
end

QA.Register("debug-w7", { title = "Speed: the skin pass after a click in a rule's editor (B293, debug W7)",
    qa = "B293", order = 518, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Rules|r and the addon starts noting each redraw. Click a rule in the sidebar, then click one switch in its editor on and off again (for example Display > Maintain aspect ratio), and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the switch changes at once. The check reads the last redraws that built this rule's editor: their time (build and draw + skin) goes into the note to compare with your J31 numbers (136 and 221 ms), and it passes when the last click's width scan measured no text again (before: every dropdown text of every rule on every click).",
        setup = function() if QA.PerfOpenRules then QA.PerfOpenRules() end end, check = Check },
    { text = "Now open the rule that was slowest for you (rule108, Fiery Brand, or the one with the most cues and triggers), click a switch in its editor on and off, and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the same: the note keeps this rule's times; it passes when the last click's width scan measured no text again.",
        check = Check },
} })
