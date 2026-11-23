#!/usr/bin/env python3
"""Platform split P3 "Options split" (Options 0.6.83; docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 7, 10 and risk R8): the rule
editor and the rules tree moved out of XayaUI_Options/Options.lua (then to XayaUI_Options/RuleEditor/, later the addon
XayaUI_Rules_Options, from Rules 0.7.0 XayaUI_Rules/Editor/, since bundle 1 round 7 XayaUI_Options/RuleEditor/ again). A pure code move: the player must get exactly the same settings window.
Loads the real addons of this branch (XayaUI, XayaUI_Options, XayaUI_Rules with its rule editor) in the stand-in game, sets up one fixed
state (rules with cues and an outcome, nested groups, a disabled rule, a buff bar, a Recycle Bin item, a fixed clock) and builds the whole
options table (ns.BuildOptionsTable, every page of every module that is on). Every node is written out: its key path, type, order, width,
name, desc, the results of hidden / disabled / get / values / sorting / confirm / image called with an AceConfig-style info table, and
every other plain field; functions that change something (set, func, validate) are only noted as present. Version strings, table
addresses, dates and error positions are normalised.
  A The dump of the new code equals the golden dump, compared per top tab (sha256 and node count), with every addon on.
  C The rule editor's own files register no settings page of their own (rules / core / cooldowns), and no module registers a page
    (this branch holds no feature addon with settings pages).
  D (P4, platform split) XayaUI Rules switched off: the window is the all-on window minus exactly the rules' own parts (the Rules tab,
    the rule list rows and Rule Creation tab of Settings, the backups and the "Rules and groups" part of Profiles); every other line is
    the same. Fails on the code before P4 (there is no XayaUI_Rules folder to switch off: the Rules tab and the backups stay).
  (B, the same comparison with each feature addon switched off in turn, and C's V14 checks of those addons' pages were removed with
  them: XayaUI Chat, QoL, Bonus Features, Blizzard Reskin, Dev Assist, Nameplates and Media are not on this branch, REQUEST-LOG A23.)
Regenerated on 2026-11-09 for the main slim-down (REQUEST-LOG A23; Rules 0.7.0, Options 0.6.107): the golden now holds the all-on
window of this branch only. Confirmed before recording: (1) the dump of this code is byte for byte the dump of the code before the
slim-down (1dc42131, with XayaUI_Rules_Options as its own addon) run with the feature addons' folders taken away (5 top tabs, 7205
lines, same hashes, same registered pages), so the editor's move changed nothing; (2) the dump of 1dc42131 with its feature addons
present reproduces the old golden's all-on "cooldowns" and "settings" hashes, and differs from this code's dump only in lines of the
retired addons: their top tabs (qol, bonus, reskin), their Profiles parts (inc_ / imp_ bonus, qol; Blizzard Reskin's part 2 places
up), their minimap list rows (Notes, Calculator, Stat Calculator, Data Panels, Chat Panel, Improved Chat, Chat privacy cover;
"XayaUI Settings" 4 -> 1), Dev Assist's Settings > Debugging rows (devPages, gameDump, sendDev: now hidden), their registered pages,
and 4 "cooldowns" lines whose order 1.05 the old dump printed as "<version>5" (XayaUI_Media's version "1.0" was normalised away
inside the number); 0 other lines.
History of the golden before the slim-down (recorded with the feature addons then on main):
The golden values below were produced by `python3 tests/options_split_parity_run.py --golden` on a checkout of bd03eb5 (the code
before the move). Regenerated once on 2026-11-08 for XayaUI 0.6.79 (PS-57, #480: reskin and module switches take effect on reload):
the dumps before and after differed in exactly 16 lines (all-on variant; 5 to 16 per variant), each only in the `desc` text of a reskin or module switch that said it applied at once
(Improved Chat, Chat Panel, Character Pane, Esc Menu, Shopping List, the 10 Blizzard Reskin pages, the Overview's "Enable Blizzard
Reskin", in every variant where that page exists); node counts, names, get / hidden / disabled results unchanged (debug-log
2026-11-08 conflicts-reload). Regenerated again on 2026-11-08 for Rules Options 0.6.79 (debug W1, #476: the Specialization lists follow
the game's spec count per class): only the "cooldowns" tab changed, in every variant, 6855 -> 6686 nodes; `--dump` of main b0723dd and of
the new code differ only in lines whose path holds `.specs` (every Specialization list; the 13 rule Load tabs drawn in full lose 13 tick boxes each: the stand-in's C_SpecializationInfo.GetNumSpecializationsForClassID
answers 3, so each class lists 3 specs instead of the 4 indexes the old loop read), 0 other lines (debug-log 2026-11-08 debug-w1). Regenerated again on 2026-11-08 for Options 0.6.97 (debug W3, #471): only the "set" and "settings"
tabs changed (the Theme page), in every variant, +48 nodes; `--dump` of main 1f7352b and of the new code differ in 280 lines per variant, all under
`theme.overrides.` (each class box's colours and Reset become table cells, plus an empty cell per missing colour) or `theme.delete`
(arg.xuiEndMargin), 0 other lines (debug-log 2026-11-08 debug-w3). Regenerated again on 2026-11-08 for Options 0.6.102 (debug W9a, #460):
only the "set" and "settings" tabs changed (the Theme page), in every variant, +2 nodes each; `--dump` of main da9b5e9 and of the new code
differ only under `theme.` (new `gradRev` and `gradTokens`, the `advanced` desc, and the `order` of the nodes after them); with order
numbers set aside, 0 other lines (debug-log 2026-11-08 debug-w9a). Regenerated again on 2026-11-08 for Options 0.6.104 / Reskin 0.6.24
(debug W9b, #472): only the "reskin" tab changed; `--dump` of accb5c8 and of the new code differ (all-on: 275 lines) only in the new
Blizzard Reskin > Theme page (`reskin.rsktheme.*`), one `xuiTheme` row ("Theme") on each element's page, the Esc Menu's Colors group
removed (`reskin.gamemenu.colors.*`, now its Theme row) with a desc on its Reset, and the `order` of the two pages sorted after "Theme"
(Toasts and Pop-ups, Tooltips); 0 other lines (debug-log 2026-11-08 debug-w9b). Regenerated again on 2026-11-08 for Chat 0.6.46 (debug
chat defaults): only the "qol" tab changed, in every variant where XayaUI Chat is on, same node count; `--dump` of 1b974fe and of the new
code differ in 16 lines per variant, all `qol.improvedchat.privacy.*` and only in their get() result (nil before: the privacy cover's
defaults never reached the saved settings in the game; now each shows its default, e.g. Button size 28, Color 0.04 | 0.04 | 0.06), 0 other
lines (debug-log 2026-11-08 debug-chatdefaults). Regenerated again on 2026-11-08 for QoL 0.7.53 (character pane split stage 1, C20): only the
"qol" and "reskin" tabs changed, in every variant where XayaUI QoL is on (QoL off: 0 lines); `--dump` of f870d78 and of the new code differ
(all-on: 609 lines) only in the four feature controls and the Stat list page moving from `reskin.charreskin.*` (ilvl, enchants, gems,
statList, statListPage: 299 nodes) to `qol.charpane.*`, node for node the same after the path (names, descs, orders, get / hidden /
disabled results), the new page node `qol.charpane` ("Character Pane", its switch), and the `order` of the QoL pages sorted after it
(Character Toolkit, Cursor, Improved Chat, Nameplates, Release Guard: +1); 0 other lines (debug-log 2026-11-08 character-split). Regenerated
again on 2026-11-08 for Bonus 0.6.37 / QoL 0.7.53 (character pane split stage 2): `--dump` of stage 1 and of the new code differ only in
(all-on, 246 lines; every variant with XayaUI QoL and Bonus Features on the same) the Stat Calculator's Panel and Spell Math parts moving
from `qol.chartoolkit.*` (panelPart, spells: 117 nodes) to `bonus.statcalc.*`, node for node the same after the path; the new page node
`bonus.statcalc` ("Character Toolkit", its own switch, the toolkit's switch texts) and its intro (the toolkit's, its parts list now
"(Panel, Spell Math)"); the `order` of the Bonus pages after it (+1); QoL's `qol.chartoolkit` switch tip and intro (they named the Stat
Calculator). XayaUI Bonus Features off (139 lines): the two parts gone with it, the minimap list's "Stat Calculator" row gone
(`settings.minimap.entries.stats`, `set.minimap.entries.stats`: the row is Bonus's) and the rows after it one `order` up, and the two QoL
texts. XayaUI QoL off: 0 lines (Bonus Features shows nothing of it). Regenerated again on 2026-11-08 for Options 0.6.105 (the Theme table's rows, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #7): only the
"reskin" tab changed; `--dump` of 3eb0c4b and of the new code differ only in the relWidth of the table's Element cells (h_el and every
el_*, 0.24 -> 0.25: 17 lines changed, i.e. 34 diff lines all-on), 0 other lines in every variant (debug-log 2026-11-08-1941). Regenerated
again on 2026-11-08 for Rules Options 0.6.82 ("Maintain aspect ratio", REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 24-25): only the
"cooldowns" tab changed, in every variant, 6686 -> 6690 nodes; `--dump` of 1c7ca2b and of the new code differ in exactly 4 added lines per
variant, each the new `pageGroup.size.body.aspect` tick box (name "Maintain aspect ratio", order 2.5, get() false) on one of the 4 group
pages the fixed state draws, 0 other lines (debug-log 2026-11-08 aspect-ratio). Regenerated again on 2026-11-08 for Rules Options 0.6.82 (Count options, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #26): `--dump` of
4bbf585 and of the new code differ only in the "Count of" selects inside each cue's Count options pane (`...cnt.body.pane_cnt.body.source`,
14 lines per variant, all-on): the old golden held `sorting()=ERR <src>: attempt to index field 'source' (a nil value)`, i.e. it had
recorded the bug; now the list's order (e.g. {1="none",2="stacks"}). 0 other lines in every variant (debug-log 2026-11-08 count-options). Regenerated again on 2026-11-08 for Bonus 0.6.38 (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #37, "these are \"Stat Calculator\""):
only the "bonus" tab, in every variant where XayaUI Bonus is on: `bonus.statcalc` is named "Stat Calculator" (was "Character Toolkit",
its switch too), and the Bonus pages, sorted by name, renumber: Data Panels 2 -> 1, Enhanced Tooltips 3 -> 2, Stat Calculator 1 -> 3
(3 lines per variant), plus the desc texts that named the path "Bonus Features > Character Toolkit" (now "... > Stat Calculator"; e.g. qol.chartoolkit.intro); 0 other lines. Regenerated again on 2026-11-08 for American spelling (FA-16, tests/american_spelling_run.py; Chat 0.6.47, Nameplates 0.2.4, Reskin 0.6.25, Rules Options 0.6.82): `--dump` of 4e4e4be and of the new code
differ in 22-25 lines per variant (same line and node counts), each only in words of a name / desc / values text: gray -> grey, Grays -> Greys,
ungrayed -> ungreyed (her exception; the Opacity & Fill / Overlay Layer descs and "(none - grey)"), colour(s / ed) -> color(s / ed), Colours -> Colors
(the Nameplates page and its switch, Friend Colors' Social note, the chat Sidebar's Background desc); a word-by-word comparison found 0 other differences. Regenerated again on 2026-11-09 (merge of the group anchors build): one help text under the group position settings respelled ("centre" -> "center", FA-16); 0 other lines. `--dump DIR` writes the full dumps, one file per variant, to compare by hand (diff) when a check fails.
recorded the bug; now the list's order (e.g. {1="none",2="stacks"}). 0 other lines in every variant (debug-log 2026-11-08 count-options).
Regenerated again on 2026-11-08 for Rules 0.6.82 (group anchors, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 14, 18, 28): only the
"cooldowns" tab changed, in every variant, 6690 -> 6694 nodes; `--dump` of 897ae70 and of the new code differ in exactly 8 removed and 12
added lines per variant, on the 4 group pages the fixed state draws: `pageGroup.container` (only its xuiInfo, the settings note that now
says what the anchor point refers to), `pageGroup.container.rel` (only its sorting / values: "Another group" added last) and the new
`pageGroup.container.relGroup` select ("Group", order 4.25, hidden while Relative to is not Another group), 0 other lines in every variant
(debug-log 2026-11-08 group-anchors). `--dump DIR` writes the full dumps, one file per variant, to compare by hand (diff) when a check fails.
Regenerated on 2026-11-10 for bundle 1 (docs/plans/RULES-REVIEW-2026-11-10.md): `--dump` of 0345f8f9 (before bundle 1; it reproduces the
old golden's every hash) and of the new code differ in 1129 lines, same 7205 nodes and paths: 1127 nodes under `.cues.` (bar, tex, anim,
bartext, txt_*, pos, color, snd_*) gain `disabled()=nil` (R6: the edit lock now covers a cue's options; not locked here) and
`set.ui.rules.draftsMax` / `settings.rules.draftsMax` change their desc to "...dropped when the window closes." (R7); 0 other lines.
Regenerated on 2026-11-10 for bundle 1 round 3 (SD-17, the group's border and background drawn on each display): `--dump` of 3eede60c
(round 2; it reproduces the old golden's every hash) and of the new code differ only in the "cooldowns" tab, 6694 -> 6698 nodes, on the
4 group / display pages the fixed state draws: the new `pageDisplay.border.body.groupNote` (one per display page: "These change each
display's own border and background. The group's ... are drawn on each display as well."), and on each `pageGroup.container`:
`boxH` renamed "Border and background on each display" with an xuiInfo note (the new boxNote text, "...one by one, not as one box
around the whole group..."), `pad` renamed "Padding around each display", and a new desc on border, borderColor, bg, bgColor, bgTex
and pad (each says "each display"); 0 other lines (the round-3 combat lock and sound changes draw no other line here).
Updated on 2026-11-11 for round 4 (SD-32, her answer "0 px (Recommended)": a group with no saved padding has 0 px): `--dump` of the
code before the change (round 3 plus the other round-4 units' edits at that moment) and of the new code differ in exactly 4 lines, all
"cooldowns", each a `pageGroup.container.pad` node on the 4 group pages the fixed state draws, only in `get()=4` -> `get()=0`; same
6698 nodes; 0 other lines. Only the all-on "cooldowns" hash changed (1877b5cde0ef9cca -> 0c8c6b423b53037c).
Updated on 2026-11-12 for round 6 (SD-53, her words: "first run ever open with settings; otherwise put a config button in the rules
pane"): `--dump` of HEAD 89ea79a and of the new code differ in exactly 4 lines: 2 added nodes in "cooldowns" (the new
`enabledTab.loaded.auraSetup` and `smartTab.all.auraSetup`, the "Open Combat Tracking Setup" button; 6698 -> 6700 nodes) and the
Rule Creation `auraSetup` group's xuiInfo text in "set" and "settings" (it no longer says the window "runs once per spec": it never
opens by itself); same node counts there; 0 other lines.
Updated on 2026-11-13 for bundle 1 round 7 (SD-57 / SD-58: the rule editor, Combat Tracking Setup, the talent scan, the editor's spell
and texture lists, the displays' right-click menu and the Minimap Button page moved into XayaUI Options; the Recycle Bin's false "every
30 minutes"): `--dump` of HEAD b4742900 (the tree before the move) and of the new code differ in exactly 1 line, "profiles" tab:
`profiles.bin.keep` desc, "Checked at login and every 30 minutes" -> "Checked when you log in or out, and whenever this list is shown or
an item is restored" (what XayaUI/RecycleBin.lua does: PLAYER_LOGIN, PLAYER_LOGOUT, ns.RecycleItems, ns.RecycleRestore); same 7211
lines; 0 other lines, so the move itself changed nothing in the window. Only the all-on "profiles" hash changed (d79e2e33d8c99bba ->
cb4b7d1248032574).
Updated on 2026-11-13 for bundle 1 round 8 (V34 audit "Core code that serves only retired QA-branch addons"; REQUEST-LOG A23 SD-61 /
SD-70): `--dump` of a snapshot of the tree with this unit's files as before (it passes the old golden: 15 checks, 0 failed) and of the new
code differ in exactly 12 lines, 6 in "set" and the same 6 in "settings": the Advanced Debugging desc (it no longer says "On by default;
it does nothing while nothing goes wrong", SD-61 made it off by default) and 5 removed nodes, minimap.where ("Show it in: Minimap / Chat
sidebar / Both"; the chat sidebar was the retired XayaUI Chat's) and Dev Assist's debug.devPages, debug.gameDump, debug.gameDump.gdOpen
and debug.send.sendDev (all hidden on main: XayaUI Dev Assist is retired). 7211 -> 7201 lines; 0 other lines. Only the all-on "set"
(19a2ae037fb40860, 238 -> 14ad1ae55fa6be62, 233) and "settings" (c8ef2369c49549df, 237 -> b53fed29e302ddee, 232) hashes changed.
Regenerated on 2026-11-12 for Bonus 0.6.45 (the Stat Calculator on main under XayaUI Bonus Features, REQUEST-LOG A24 #10): `--dump` of
origin/main ad60a05 and of the new code (all-on) differ only in the new top tab `bonus` and its 118 `bonus.statcalc.*` lines (the
Stat Calculator page as on qa-installer-branch, with the panel switch's and intro's texts for main), the minimap list's new "Stat
Calculator" row (`set.minimap.entries.stats`, `settings.minimap.entries.stats`: hidden while the Stat Calculator is off) and the
"XayaUI Settings" row after it one `order` down (1 -> 2), 0 other lines. The new variant off-XayaUI_Bonus has the hashes the all-on
window had before (ad60a05's golden) for every tab but "cooldowns" (same node count), whose dump differs from ad60a05's all-on dump
only in the random group and rule ids (the second window built in the process: see main() below), 0 other lines. C now expects the Bonus Features page "statcalc" and no other module page.
Regenerated on 2026-11-12 for Bonus 0.6.46 / Options 0.6.108 (REQUEST-LOG A24 #12 / #13: the Stat Calculator loads on demand; its
settings travel in profiles): `--dump` of c4ae19b and of the new code (all-on, the Stat Calculator off as in a fresh install) differ
only in (1) `bonus.statcalc`: its switch's desc (her option text "Off means it is never read; on means it loads once per reload."),
the 118 `bonus.statcalc.*` lines of the detailed page gone (they come with the loaded calculator) and one `bonus.statcalc.note` line
added; (2) Profiles: the new "Bonus Features" tick box under Export (`inc_bonus`, order 5) and Import (`imp_bonus`, order 8), with
"Blizzard Reskin" one place down (5 -> 6, 8 -> 9); 0 other lines. off-XayaUI_Bonus: 0 lines differ.
Regenerated on 2026-11-15 for the merge of main fda1e293 (Bonus 0.6.46, Options 0.6.108) into bundle 1 (branch ae2f396e), with
`--golden` on the merged code; the JSON was not merged by hand. `--dump` of the branch (ae2f396e), of main (fda1e293), of their merge
base ad60a05 and of the merged code: a three-way text merge (git merge-file) of the two sides' dumps over ad60a05's reproduces the merged
dump exactly in both variants (0 lines differ; off-XayaUI_Bonus compared with ad60a05's and the branch's all-on dumps after the random
group / rule ids are masked, as main's note above explains), so every changed line comes from one side. All-on, merged against the
branch: 15 diff lines, 7201 -> 7208, all from main (the `bonus` tab, `bonus.statcalc` and `bonus.statcalc.note`; `inc_bonus` and
`imp_bonus` with Blizzard Reskin 5 -> 6 and 8 -> 9; `minimap.entries.stats` with "XayaUI Settings" 1 -> 2 in "set" and "settings"):
3 + 2 + 2 = 7 added lines and 4 changed lines (7 + 4 x 2 = 15). Merged against main: 2340 diff lines, all from bundle 1 (the notes
from 2026-11-10 to 2026-11-13 above). off-XayaUI_Bonus: the branch's all-on window (same hashes for "profiles", "set" and "settings":
cb4b7d1248032574, 14ad1ae55fa6be62, b53fed29e302ddee; "cooldowns" differs only in the random ids).
Updated on 2026-11-17 (bundle 1 round 10, Stat Calculator repair 1): only the all-on "bonus" entry, 211f2cc16dc30394 -> 6a81bd4fee213ffb,
3 nodes both. `--dump` before and after differ in 1 line, `bonus.statcalc`: its switch's hover text drops "Turns the Stat Calculator on
or off." and reads "On, the Stat Calculator loads the first time you open it. Off, nothing of it runs; once it has loaded, its memory is
freed at your next /reload." (tests/hover_brevity_run.py: at most two sentences; it had three). The value is the one `--golden` writes on
a copy of the tree; that copy's "cooldowns" entries (another unit's change) were not taken over.
Updated on 2026-11-17 (bundle 1 round 10, calculator unit; SD-95 / SD-115 / SD-116: the arithmetic Calculator, its own page and its own
minimap row inside XayaUI Bonus Features): only all-on entries, "bonus" 6a81bd4fee213ffb (3 nodes) -> 4c373448aa500b52 (8), "set"
5506788f272a74ab (234) -> 4205a4a9b040d813 (235), "settings" 504240cced864385 (233) -> 94a60d23311175f0 (234) and the registered pages
(bonus=statcalc -> bonus=calculator,statcalc). `--dump` before (a copy without XayaUI_Bonus/Calculator.lua) and after differ, apart from
the "cooldowns" random ids, in: `bonus.calculator` and its four lines (about, how, open, reads: 3 + 5 = 8 nodes), `bonus.statcalc` order
1 -> 2, and in "set" and "settings" the new `minimap.entries.calc` row ("Calculator") with the two other rows' order + 1 (234 + 1 = 235,
233 + 1 = 234). off-XayaUI_Bonus: 0 lines. The values are the ones `--golden` writes on a copy of the tree; that copy's "cooldowns"
entries (another unit's change) were not taken over.
Updated on 2026-11-17 (bundle 1 round 10, calculator repair 1; CHAT-6, the short word /calc): only the all-on "bonus" entry,
4c373448aa500b52 -> 846d5e8f1ac01082, 8 nodes both. `--dump` before (the pre-repair Calculator.lua) and after differ in 2 lines
(4 diff lines), both on the Calculator's page: `bonus.calculator` (its switch's tip and desc name /calc too) and `bonus.calculator.how`
(names /calc, and says /calc is left to another addon that already uses it; /xui calc always works). off-XayaUI_Bonus: 0 lines. The
value is the one `--golden` writes on a copy of the tree; that copy's "cooldowns" entries (another unit's change) were not taken over.
Updated on 2026-11-18 (bundle 1 round 11a; the stale golden of the round 10 final review, blocker 3 (a)): only the "cooldowns" entries,
all-on 0b5c193a92951b7c -> 4ce0abe5f2f4db45 and off-XayaUI_Bonus 27a61cac8a959437 -> 123e2c0caecfc428, 6700 nodes both. `--dump` of
68432825 (round 9's end; it passes its golden, 23 checks, 0 failed) and of round 10's code (dd80f897, and the working tree then, whose
dumps are byte for byte the same) differ in "cooldowns" in 15 lines per variant and nothing else: the `snd_gameSoundOn` switch of the
sound cue (2 nodes) and the 13 `actions` nodes that carry its pane in `xuiParts`; replacing the old hover text by the new one in the
old dump gives the new dump exactly. The hover text is the sound unit's rewrite (SD-96 / SD-107, XayaUI_Options/RuleEditor/Editor.lua):
old "Plays this sound file when the trigger's aura is gained or lost, even in combat; the rule's other triggers, conditions and Repeat
are ignored. Set up out of combat only.", new "The game plays this sound file when the aura is gained or lost, even in a fight while the
aura is hidden, following the Load tab but never Repeat or the rule's other triggers. If this buff is in your Cooldown Manager, XayaUI
plays the sound itself instead and follows every setting of the rule." The other all-on lines that differ from 68432825 (6 gone,
13 new: the Calculator's page, `bonus.statcalc` and its note, the `minimap.entries.calc` rows) are round 10's already recorded entries.
The golden also holds, from now on, a per-node record ("nodes": one 10-digit hash per dump line, in dump order). A failed tab hash then
names the nodes behind it ("now differs", "new", "gone"), and a check keeps that record in step with the tab hashes.
Updated on 2026-11-19 (bundle 1 round 11a, error record repair 2; SD-139: errors and warnings are saved whether or not Advanced
Debugging is on): only the "set" and "settings" entries of both variants, all-on 4205a4a9b040d813 -> d70722819b0f933f (235) and
94a60d23311175f0 -> 20b4b7ad4c87cebe (234), off-XayaUI_Bonus 14ad1ae55fa6be62 -> eef50c818c99a7b9 (233) and b53fed29e302ddee ->
73192a600e72024c (232), one node each (index 2). `--dump` before (the tree with the pre-repair XayaUI_Options/Options.lua) and after differ
in exactly 4 lines, `set.debug.advancedDebug` and `settings.debug.advancedDebug` in each variant: the switch's hover text, old "Records
XayaUI's own errors and warnings for the debug report (/xui report) and, from your next login or /reload, loads the debug tools: ...
Off by default.", new "Shows XayaUI's own Lua errors where its messages go and, from your next login or /reload, loads the debug tools:
... (errors and warnings are saved either way). Off by default." (tests/fix_r11_error_record_run.py G1 / G5).
Updated on 2026-11-21 (bundle 1 round 11a final fix; SD-139, R11A final review concern "SD-139 wording": the Bug report's count,
ns.ErrorCount, counts every saved entry, warnings included): only the "set" and "settings" entries of both variants, all-on
d70722819b0f933f -> 5214ec2426f252c0 (235) and 20b4b7ad4c87cebe -> 3bb895f8859c7af4 (234), off-XayaUI_Bonus eef50c818c99a7b9 ->
0551f587693a5588 (233) and 73192a600e72024c -> 233c8ad386b7f8db (232), one node each (index 6). `--dump` before (the tree with the
previous XayaUI_Options/Options.lua) and after differ in exactly 4 lines, `set.debug.bug.bugInfo` and `settings.debug.bug.bugInfo` in
each variant: old "XayaUI keeps its own Lua errors (0 so far, 0 different) ...", new "XayaUI keeps its own errors and warnings (0 so
far, 0 different) ..." (tests/fix_r11_error_record_run.py G4 / G4b). The values are the ones `--golden` writes on a copy of the tree.
Updated on 2026-11-22 (bundle 1 round 11b, triage unit; logger handover). Every changed line was traced by three dumps before re-recording:
round 11a's tree 18798861 (passes the old golden, 26/0), this tree's addon folders with 18798861's harness ("mix"), and this tree.
(1) 18798861 -> mix differs in exactly 4 lines, the new toggle `set.debug.runLogger` and `settings.debug.runLogger` (name "Advanced
debug logging", order 11.05; SD-123 / SD-149) in each variant: the only change of addon code. set/settings: one node inserted at index
17, every other node equal (5214ec2426f252c0 -> 986774c91fed5c9f (236), 3bb895f8859c7af4 -> 50de2efdcbc5c959 (235); off-XayaUI_Bonus
0551f587693a5588 -> 3e56e9c5196a683e (234), 233c8ad386b7f8db -> f0455e3b8fbb5c7f (233)). (2) mix -> this tree differs only in the
"cooldowns" tab, 38 nodes per variant (76 diff lines), all from the stand-in becoming truer (hidden-data fight, spec section 7 risk 8),
no addon code: (a) 6 `rule.status` lines read "cooldown unknown (cooldown hidden in combat, no estimate yet)" out of combat under the old
stand-in, because its GetSpellCooldown had no isActive field (Conditions.lua reads cdActive == nil as hidden); the new stand-in answers
isActive (NeverSecret, structures.md SpellCooldownInfo) and nothing is restricted out of combat (PRED:80-93), so they read "cooldown OK
(single-charge)"; (b) 32 hint lines (`trigger.ruleCombat` 11, `cdCombat` 6, `buffCombat` 5, `cdmWarn` 10) are now shown, because the old
stand-in answered GetSpellAuraSecrecy / GetSpellCooldownSecrecy 0 (NeverSecret) for every spell and the new one answers the game's
default for an unknown spell, 2 (ContextuallySecret; spec section 2.2, PRED:27-31). These are the hints the addon already shows in game
for such spells; no visible behaviour was chosen, so this is not spec F4's decision. cooldowns 4ce0abe5f2f4db45 -> 1a56a0b579a2f0fb
(6700), off-XayaUI_Bonus 123e2c0caecfc428 -> c9f6329c22a62c77 (6700). The values are the ones `--golden` writes on this tree.
The golden needs the API index (XUI_API_INDEX, default tests/harness/api_index.json, not in git): without it the dump differs (no Enum.SecrecyLevel).
Run: python3 tests/options_split_parity_run.py"""
import difflib, hashlib, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

GOLDEN_FILE = os.path.join(HERE, "options_split_parity_golden.json")
# (REQUEST-LOG A23) this branch held no feature addon to switch off in turn. (Bonus 0.6.45, A24 #10) XayaUI Bonus Features is on main
# with the Stat Calculator only: the golden holds the all-on window and the window with it switched off
MODULES = ["XayaUI_Bonus"]


LUA = r'''
return function(W, L)
-- a fixed clock: Recycle Bin dates and "removed for good in" read time() / date()
local T0 = 1790000000
local osdate, ostime = os.date, os.time
rawset(_G, "time", function(t) if t then return ostime(t) end return T0 end)
rawset(_G, "date", function(f, t) return osdate(f, t or T0) end)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
if not (ns and ns.BuildOptionsTable) then return { "the settings window did not load" } end
-- the fixed state (P4: none while XayaUI Rules is off; there are no rules then)
if ns.NewRule then
local function rule(name, enabled) local r = ns.NewRule(); r.name = name; r.enabled = enabled; ns.NormalizeRule(r); return r end
ns.folders = {}
local g1 = ns.NewFolder and ns.NewFolder("Group One") or nil
local g2 = ns.NewFolder and g1 and ns.NewFolder("Inner Group", g1.id) or nil
local A = rule("Shell", true); A.useBuff = true; A.buffID = 48707; A.buffState = "present"
local B = rule("Cooldown watch", true); B.spellID = 47528; B.cdState = "ready"; if g1 then B.folder = g1.id end
local C = rule("Switched off", false); if g2 then C.folder = g2.id end
local D = rule("Sound only", true); D.spellID = 49576
ns.rules = { A, B, C, D }
pcall(ns.NewCueRule, A, "icon"); pcall(ns.NewCueRule, A, "text"); pcall(ns.NewCueRule, D, "sound"); pcall(ns.NewCueRule, B, "bar")
local E = rule("Deleted later", true); ns.rules[#ns.rules + 1] = E
if ns.RecycleRule then pcall(ns.RecycleRule, E) end
if ns.MarkDirty then pcall(ns.MarkDirty) end
end
W.tick(0.1, 3)
local root = ns.BuildOptionsTable()
-- the dump
local lines = {}
local function norm(s)
  s = tostring(s)
  s = s:gsub("0x%x+", "<addr>"):gsub("(%a+): <addr>", "%1"):gsub("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d", "<date>")
  s = s:gsub("[%w_/%.%-]+%.lua:%d+:", "<src>:")
  return s
end
local function ser(v, depth, seen)
  local t = type(v)
  if t == "function" then return "fn" end
  if t == "string" then return (string.format("%q", norm(v)):gsub("\\\n", "\\n")) end   -- one line per node
  if t ~= "table" then return norm(v) end
  seen = seen or {}
  if seen[v] then return "<cycle>" end
  if depth > 4 then return "{...}" end
  seen[v] = true
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1, seen) end
  seen[v] = nil
  return "{" .. table.concat(out, ",") .. "}"
end
local CALL = { name = true, desc = true, hidden = true, disabled = true, get = true, values = true, sorting = true, confirm = true,
  image = true, imageWidth = true, imageHeight = true, order = true, width = true, descStyle = true, confirmText = true }
local function call(fn, info)
  local res = { pcall(fn, info) }
  if not res[1] then return "ERR " .. norm(res[2]) end
  local out = {}
  for i = 2, math.max(2, table.maxn(res)) do out[#out + 1] = ser(res[i], 0) end
  return table.concat(out, " | ")
end
local function walk(node, path, depth)
  if type(node) ~= "table" or depth > 40 then return end
  local info = { options = root, option = node, arg = node.arg, type = node.type, handler = node.handler, uiType = "dialog",
    uiName = "CueRules", appName = "CueRules" }
  for i, k in ipairs(path) do info[i] = k end
  local keys = {}
  for k in pairs(node) do if k ~= "args" and k ~= "plugins" then keys[#keys + 1] = k end end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = node[k]
    if type(v) == "function" and CALL[k] then parts[#parts + 1] = tostring(k) .. "()=" .. call(v, info)
    else parts[#parts + 1] = tostring(k) .. "=" .. ser(v, 1) end
  end
  lines[#lines + 1] = table.concat(path, ".") .. " :: " .. table.concat(parts, " ; ")
  if type(node.args) == "table" then
    local ks = {}
    for k in pairs(node.args) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(ks) do
      local p = {}
      for i, x in ipairs(path) do p[i] = x end
      p[#p + 1] = tostring(k)
      walk(node.args[k], p, depth + 1)
    end
  end
end
walk(root, {}, 0)
-- C: which modules registered pages
local reg = {}
for _, m in ipairs({ "chat", "qol", "bonus", "reskin", "debugging", "nameplates", "media", "rules", "core", "cooldowns" }) do
  local ks = {}
  for k in pairs(ns.BuildSettingsPages(m, function() end)) do ks[#ks + 1] = k end
  table.sort(ks)
  reg[#reg + 1] = m .. "=" .. table.concat(ks, ",")
end
return { "ok", table.concat(lines, "\n"), table.concat(reg, " ") }
end
'''


def versions():
    out = {}
    for name, d in H.find_addons().items():
        toc = open(os.path.join(d, name + ".toc"), encoding="utf-8").read()
        m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
        if m:
            out[name] = m.group(1)
    return out


def run_variant(off):
    folders = H.find_addons()
    enabled = [n for n in folders if n != off]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        # (round 7, REQUEST-LOG A23 SD-58 / SD-61) Advanced Debugging is off for a new install now (it was on by default, and the console
        # and reports are XayaUI_Debug's, read only while it is on): saved on here, as every install before round 7 has it, so the
        # comparison with the old build stays like for like (the old code saves the same "on" itself; the same checks pass on 2381c09d)
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {"XayaUI": {"CueRulesDB": {"ui": {"advancedDebug": True}}}}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    if res[1] != "ok":
        return None, None, errs + [str(res[1])]
    dump = str(res[2])
    # version strings: the addons whose code changes take a new version; the dump must not depend on it
    for name, ver in sorted(versions().items(), key=lambda kv: -len(kv[1])):
        dump = dump.replace(ver, "<version>")
    return dump, str(res[3]), errs


def node_path(line):
    """The key path of one dump line ("" for the root node)."""
    return line.split(" :: ", 1)[0]


def split_tabs(dump):
    """The dump's lines per top tab, in dump order (the walk visits keys sorted, so the order is fixed)."""
    tabs = {}
    for line in dump.split("\n"):
        path = node_path(line)
        top = path.split(".", 1)[0] if path else "<root>"
        tabs.setdefault(top, []).append(line)
    return tabs


def node_digest(lines):
    """One short hash per node line, in dump order: the golden's per-node record. It only serves to NAME the nodes behind a failed tab
    hash (the tab hash stays the check); 10 hex digits, so a chance collision among ~7,200 lines is negligible (about 2.4e-5)."""
    return [hashlib.sha256(l.encode("utf-8")).hexdigest()[:10] for l in lines]


def summarise(dump):
    tabs = split_tabs(dump)
    return ({t: [hashlib.sha256("\n".join(ls).encode("utf-8")).hexdigest()[:16], len(ls)] for t, ls in sorted(tabs.items())},
            {t: node_digest(ls) for t, ls in sorted(tabs.items())})


def name_node_differences(lines, want_digest, limit=12):
    """Names the nodes of one tab that differ from the golden's per-node record (round 11a: a stale golden must say WHICH node moved).
    The golden keeps hashes only, so a node is named by its path in this dump: "now differs" (a golden node replaced in place, i.e. its
    text changed), "new" (no golden node there) or "gone" (golden nodes with no counterpart, named by the node just before them).
    Returns a list of short strings, at most `limit` plus a count of the rest."""
    if not want_digest:
        return ["the golden holds no per-node record for this tab; record one with --golden after proving the change"]
    cur = node_digest(lines)
    paths = [node_path(l) or "<root>" for l in lines]
    out = []
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, want_digest, cur, autojunk=False).get_opcodes():
        if op == "equal":
            continue
        both = min(i2 - i1, j2 - j1)
        out += ["now differs: " + paths[j] for j in range(j1, j1 + both)]
        out += ["new: " + paths[j] for j in range(j1 + both, j2)]
        if i2 - i1 > both:
            where = ("after " + paths[j1 + both - 1]) if j1 + both > 0 else "at the start of the tab"
            out.append("gone: %d golden node(s) %s" % (i2 - i1 - both, where))
    return out[:limit] + (["... and %d more" % (len(out) - limit)] if len(out) > limit else [])


def main():
    dump_dir = None
    if "--dump" in sys.argv:
        dump_dir = sys.argv[sys.argv.index("--dump") + 1]
        os.makedirs(dump_dir, exist_ok=True)
    # the groups' ids come from the process-wide random sequence, so the "cooldowns" hash only matches when the all-on window is the
    # first one built in the process, as when the golden was recorded
    variants = [None] + MODULES
    results = {}
    dumps = {}
    errs_all = []
    for off in variants:
        tag = "all-on" if off is None else ("off-" + off)
        dump, reg, errs = run_variant(off)
        errs_all += [(tag, e) for e in errs]
        if dump is None:
            results[tag] = None
            continue
        if dump_dir:
            open(os.path.join(dump_dir, tag + ".txt"), "w", encoding="utf-8").write(dump + "\n")
        tabs, nodes = summarise(dump)
        results[tag] = {"tabs": tabs, "registered": reg, "nodes": nodes}
        dumps[tag] = dump
    if "--golden" in sys.argv:
        json.dump(results, open(GOLDEN_FILE, "w", encoding="utf-8"), indent=1, sort_keys=True)
        print("golden written: %s (%d variants, %d Lua errors)" % (GOLDEN_FILE, len(results), len(errs_all)))
        for tag, e in errs_all:
            print("ERROR in the game stand-in [%s]: %s" % (tag, e[:400]))
        return
    golden = json.load(open(GOLDEN_FILE, encoding="utf-8"))
    total = bad = 0

    def check(name, ok, detail=""):
        nonlocal total, bad
        total += 1
        if not ok:
            bad += 1
        print(("PASS " if ok else "FAIL ") + name + (("  " + detail) if (detail and not ok) else ""))

    for off in [None] + MODULES:
        tag = "all-on" if off is None else ("off-" + off)
        got, want = results.get(tag), golden.get(tag)
        check("[%s] the options table builds" % tag, got is not None)
        if got is None or want is None:
            check("[%s] golden present" % tag, want is not None)
            continue
        keys = sorted(set(got["tabs"]) | set(want["tabs"]))
        lines = split_tabs(dumps[tag])
        want_nodes = want.get("nodes") or {}
        for t in keys:
            nm = "[%s] %s: same nodes, names, descs, types, widths, hidden / disabled / get results as before the move" % (tag, t)
            same = got["tabs"].get(t) == want["tabs"].get(t)
            # (round 11a) a failed hash names the nodes behind it, so a stale golden is diagnosable without a second dump
            check(nm, same, "" if same else "got %s want %s; %s" % (got["tabs"].get(t), want["tabs"].get(t),
                  "; ".join(name_node_differences(lines.get(t, []), want_nodes.get(t)))))
        # the per-node record must agree with the hashes it explains: one entry per node of every tab, and equal to this dump's wherever
        # the tab hash is equal (else a later failure would name the wrong nodes)
        stale = [t for t in want["tabs"] if len(want_nodes.get(t) or []) != want["tabs"][t][1]
                 or (got["tabs"].get(t) == want["tabs"][t] and want_nodes.get(t) != got["nodes"].get(t))]
        check("[%s] the golden's per-node record agrees with its tab hashes (it names the nodes behind a failed hash)" % tag, not stale,
              "stale or missing for: %s" % stale)
        check("[%s] the same settings pages are registered per module" % tag, got["registered"] == want["registered"],
              "got %s want %s" % (got["registered"], want["registered"]))
    # D (P4) XayaUI Rules switched off: no golden from the old code (the module did not exist). The window is the all-on window minus
    # exactly what belongs to the rules (the Rules tab, the rule list rows and the Rule Creation tab of Settings, the backups and the
    # "Rules and groups" tick boxes of Profiles); everything else is line for line the same. Lines that differ for a known reason:
    # the Recycle Bin (no rule could be deleted into it) and the order numbers of the other profile parts (one part fewer before them).
    on_dump, _, _ = run_variant(None)
    off_dump, off_reg, off_errs = run_variant("XayaUI_Rules")
    errs_all += [("off-XayaUI_Rules", e) for e in off_errs]
    check("[off-XayaUI_Rules] the options table builds", off_dump is not None)
    if off_dump is not None and on_dump is not None:
        on_lines, off_lines = set(on_dump.split("\n")), set(off_dump.split("\n"))
        path = lambda l: l.split(" :: ", 1)[0]
        RULES_ONLY = re.compile(r"^(cooldowns(\..*)?|(set\.ui|settings)\.rules(\..*)?|(set\.ui\.display|settings\.ui)\.(displayHeader|parentGradient|"
                                r"selStyle|sidebarSpellIcons)|profiles\.export\.(savedH|backupIntro|saveName|savePick|save|p\d+(\..*)?)|"
                                r"profiles\.(export\.inc|import\.imp)_rules)$")
        KNOWN = re.compile(r"^(profiles\.bin(\..*)?|profiles\.(export\.inc|import\.imp)_\w+)$")
        removed = sorted(path(l) for l in on_lines - off_lines)
        added = sorted(path(l) for l in off_lines - on_lines)
        check("[off-XayaUI_Rules] the Rules tab is absent", not any(path(l) == "cooldowns" for l in off_lines))
        check("[off-XayaUI_Rules] the Rule Creation tab, the rule list rows and the backups are absent",
              not any(re.match(r"^((set\.ui|settings)\.rules|profiles\.export\.(savedH|save|saveName|savePick))$", path(l)) for l in off_lines))
        bad_removed = [p for p in removed if not (RULES_ONLY.match(p) or KNOWN.match(p))]
        bad_added = [p for p in added if not KNOWN.match(p)]
        check("[off-XayaUI_Rules] every other line of the window is the same as with XayaUI Rules on (%d lines gone, all the rules' own)" % len(removed),
              not bad_removed and not bad_added, "unexpected: gone %s / new %s" % (bad_removed[:8], bad_added[:8]))
        inc_on = sorted(re.search(r'name="([^"]+)"', l).group(1) for l in on_lines if path(l).startswith("profiles.export.inc_"))
        inc_off = sorted(re.search(r'name="([^"]+)"', l).group(1) for l in off_lines if path(l).startswith("profiles.export.inc_"))
        check("[off-XayaUI_Rules] Profiles > Export offers every part but \"Rules and groups\"",
              inc_off == sorted(x for x in inc_on if x != "Rules and groups") and "Rules and groups" in inc_on, "%s / %s" % (inc_on, inc_off))
        reg = dict(x.split("=", 1) for x in (off_reg or "").split())
        check("[off-XayaUI_Rules] the other modules register the same settings pages as with it on",
              off_reg == results["all-on"]["registered"], "%s / %s" % (off_reg, results["all-on"]["registered"]))
    # (round 11a) the naming itself, on this run's real all-on dump: one node's text changed, one node removed and one added must be named
    # by path and kind, and nothing else (a test of the diagnosis, so a broken one cannot hide behind a passing golden)
    if dumps.get("all-on"):
        tab_lines = max(split_tabs(dumps["all-on"]).values(), key=len)
        k = len(tab_lines) // 2
        # node k changed, node k + 2 removed, a node added after node k + 4
        mutated = (tab_lines[:k] + [tab_lines[k] + " ; mutated=1", tab_lines[k + 1]] + tab_lines[k + 3:k + 5]
                   + [node_path(tab_lines[k + 4]) + "_new :: name=\"x\""] + tab_lines[k + 5:])
        got_names = name_node_differences(mutated, node_digest(tab_lines))
        want_names = ["now differs: " + node_path(tab_lines[k]), "gone: 1 golden node(s) after " + node_path(tab_lines[k + 1]),
                      "new: " + node_path(tab_lines[k + 4]) + "_new"]
        check("a failed tab hash names the node that changed, the node that is gone and the node that is new (self-check on the real dump)",
              got_names == want_names, "got %s want %s" % (got_names, want_names))
    allon = results.get("all-on")
    if allon:
        reg = dict(x.split("=", 1) for x in allon["registered"].split())
        check("the rule editor registers no settings page of its own (rules / core / cooldowns)",
              all(reg.get(m) == "" for m in ("rules", "core", "cooldowns")))
        # (bundle 1 round 10, calculator unit, intended change; SD-95 / SD-115 / SD-116) Bonus Features also registers the arithmetic
        # Calculator's page (XayaUI_Bonus/Calculator.lua)
        check("no module registers a settings page but XayaUI Bonus Features' Calculator and Stat Calculator (bonus = calculator,statcalc; main holds no other feature addon with pages)",
              all(v == "" for k, v in reg.items() if k != "bonus") and reg.get("bonus") == "calculator,statcalc" and len(reg) == 10, allon["registered"])
    for tag, e in errs_all:
        print("ERROR in the game stand-in [%s]: %s" % (tag, e[:600]))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all else 0)


if __name__ == "__main__":
    main()
