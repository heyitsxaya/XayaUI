# Engine containers fail to build: "attempt to index field 'dirtyFlags'" (XayaUI 0.5.87 / engine 0.3.0 -> 0.3.1, fork: main)
Logged 2026-11-03 ~00:40 UTC. GitHub issue: #308 (also #306). Xaya pasted (8x, one per group):
Blizzard_SharedXML/MixinUtil.lua:398: attempt to index field 'dirtyFlags' (a nil value) -> MarkDirty <- Blizzard_CustomAuraContainer.lua:586 (OnLoad) <- CreateFrame <- XayaUI_CombatEngine/AuraDisplay.lua:225 <- Build.
Cause (verified in Blizzard's published UI source, live branch): CustomAuraContainerTemplate is an <AuraContainer> element; the dirty-state table is made by ManagedAuraContainerPrivateMixin:OnLoad_Intrinsic, which only runs for the intrinsic AuraContainer widget type. AuraDisplay created it with CreateFrame("Frame", ...), so the intrinsic OnLoad never ran and the template's OnLoad hit nil dirtyFlags. Every group failed, was caught, and fell back to XayaUI's own icons: the engine never drew anything, which is why durations were still missing.
Fix: CreateFrame("AuraContainer", ...). Every other container / button method called was checked to exist in the same source. Test now asserts the widget type.
Note: the two previous debug-log file names (0100, 0130) carry wrong times; the real commit times were 00:19 and 00:30 UTC.
Unverified in game: that the container now builds and draws durations.
Files: XayaUI_CombatEngine/AuraDisplay.lua, XayaUI_CombatEngine/XayaUI_CombatEngine.toc, tests/aura_display_run.py, MANIFEST.md5.
