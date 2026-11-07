# The settings window: a click builds only the rule editor on screen (Options 0.6.69, Dev Assist 0.7.19)

Session: perf successor (session_014bN6tTqaMKxGcnwALJ4CoU), from docs/process/handoffs/perf-test.md section 5 (known gap).
Request: REQUEST-LOG A15 P-16 (relayed O-133 / O-147 / O-149), Xaya's words: "clicking off options causes a 2s delay between click
and actualization". Target (hub registry): a click < 100 ms. QA flow question Q-PERF-5 asked whether to build this; it was built
because the tests below prove it gives the same tree and the same saved data as before (blind decision, sent to the QA flow).

## Measured cause (stand-in, whole-addon harness, 313 rules, a rule open in the editor)
Options 0.6.68 made one full build per click. Profiled (instruction-count sampling and memory deltas, scratchpad only):
- the 313 rule editors (BuildRule): ~150 of ~165 MB of garbage per click and about half the build time (~480 KB per rule);
- ns.InfoPass sorted the keys of every group in the tree, rule lists of hundreds of entries included: about a third of a click;
- ns.CuesOf / ns.FindParentRule outside the engine step read every rule per call, asked for every rule (build) and every row;
- the sidebar's up / down arrows (Siblings) read every rule's scope, group and parent for every visible row: once the editors were
  no longer built, three quarters of what was left.

## Change (XayaUI_Options/Options.lua)
- Tree.Get (the window's build) sets Tree.lazy: each rule gets its sidebar row only (ns.OptionsApi.RuleStub: the same name, hidden
  and order functions as the editor's group, now shared as ns.OptionsApi.RuleRowName / RuleRowHidden) plus the data fixes the editor
  build makes (ns.OptionsApi.RuleDataFixes: outline defaults, icon cues use the spell icon, ns.SeedArtAspect).
- ns.OptionsApi.FillRule builds the editor into that same table, with its embedded outcomes / cues and the after-passes the full
  build runs (InfoPass, HalfInputs). Called from a wrapper on AceConfigDialog.FeedGroup for every row-only rule on the drawn path
  (other addons' apps pass straight through), and SelectGroup marks the rules named in its path for a full build (Tree.want).
- A direct ns.BuildOptionsTable() (tests, Skin.lua's fallback) still builds every rule in full.
- ns.OptionsApi.WithCueMemo: during one build / one sidebar decoration, ns.CuesOf and ns.FindParentRule answer from one pass over
  the rules (same lists, same order, a copy per call; restored after, also on an error); ns.OptionsApi.memo holds per-pass answers
  that Siblings uses (scope, group, parent per rule; rule lists per group). Not used inside an engine step.
- ns.InfoPass skips the sort for a group with no description that can move (the sort only decides which heading such a description
  joins); orders are read once per entry.
- Skin.lua ScanDropdowns (window minimum width; Skin.lua itself unchanged) scans the window's last tree, which now holds only the
  editors built so far: FillRule resets of.xuiDD so the next pass looks again. Behaviour change: the narrowest width follows the dropdowns of the rules shown so far, not of every rule
  (INFERENCE that this is unnoticeable: most dropdown lists are the same media lists for every rule). Sent to the QA flow.

## Scope (V4: git grep of every reader of the window's tree)
- Readers of the tree: AceConfigDialog (FeedGroup / SelectGroup / GroupSelected / Open, Libs copy), Skin.lua ScanDropdowns
  (LastTree), DevAssist QAWalks-display.lua AdvOpt (Settings page only), ApplyTreeFilter (stops at rule rows), PickerInto (skips
  groups), EmbedOutcome (filled parents only). Tests call ns.BuildOptionsTable() directly (full).
- ns.CuesOf callers in the build / decorate paths: SmartMatch, PreviewTargets, PvFilter, cue labels; ns.FindParentRule: IsLoaded,
  IsNestedOutcome, BuildOptions' outcome loop.

## Numbers (stand-in; real numbers come from J28)
| Measure (313 rules, a rule open) | Options 0.6.68 | Options 0.6.69 |
|---|---|---|
| a click: Lua time, median of 5 | 1,715 ms | 114 ms |
| a click: garbage | 239.8 MB | 17.2 MB |
| a click, no rule open | 0.5-0.9 s, ~165 MB | ~37 ms, ~6 MB |
| first open: builds | 1 (0.6-0.8 s) | 1 (~40 ms) |
About 17% of the sampled instructions of a click are the stand-in's own frame API (C in the game). What is left is mostly
AceConfigDialog drawing the open rule's editor after each change (library behaviour) and the sidebar rows' decoration.

## Tests
- tests/options_click_cost_run.py (new; 39 checks): saved data after the window's build = after a full build (13,114 lines); the
  window's tree with every editor filled in = the full build's Rules tab (342,213 lines; control: two full builds); rule rows' name /
  order / search-hidden; validation answer unchanged; the info-icon pass = Options 0.6.68's (verbatim copy in the test; 464 info icons);
  CuesOf / FindParentRule / Siblings parity during a pass (417 rows); the window: SelectGroup to a rule, a click = one build + one editor,
  < 30 MB, a SelectGroup path into a rule's tab, a tree click on another rule, rename on / off screen, delete, move, close.
  Negative control on Options 0.6.68: 6 FAIL (no row-only rules, 239.8 MB per click, no editor-only fill).
- tests/options_open_cost_run.py: unchanged, passes.
- Dev Assist QAWalks-perf.lua: walkthrough J28 (prefill: last redraw time < 100 ms with a rule open; the selected rule's editor
  built; questions: rule search result, rename, narrowest width).
