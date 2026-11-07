# Cooldown Manager tracking: behaviour review of a reference addon (2026-11-06)

For B4 ("Enable tracking" workaround) and #278 item 2 (Xaya: "refer to EUI codebase to see how you can manually add buff tracking through his
cooldown manager"; B4: "EUI allows you to add extra things to track via custom aura bars -- we can figure out workarounds like overlaying
textures on them and setting the actual bars to zero"). Reference addons are for checking behaviour only: nothing below is code, data or text
from it; it records what behaviour was observed and which Blizzard API names are involved (facts). Read from the Drive folder
"EllesmereUICooldownManager" (version 9.7.2 per its TOC, files dated 2026-11-01), read only, by a helper agent; nothing run.
Our implementation, when built, is independent.

## What it does (behaviour)
1. It never adds anything to Blizzard's tracking list itself: no Cooldown Manager settings / layout setter is called. The only
   C_CooldownViewer call seen reads (GetCooldownViewerCooldownInfo). A spell must already be tracked by the player in Blizzard's own
   Cooldown Manager (Tracked Bars); the addon then draws its OWN bar for it and takes the state from Blizzard's item.
2. Hidden-in-combat auras (secret values) work by mirroring Blizzard's own Cooldown Manager item frames: active = the item's IsActive();
   the bar's fill copies the Blizzard bar's min / max / value (secret values pass straight through to SetValue); time text from an
   engine-formatted copy or Blizzard's own text. Thresholds on a secret duration go through C_CurveUtil step curves
   (EvaluateRemainingDuration). Fallback when no Blizzard item: C_UnitAuras.GetPlayerAuraBySpellID / GetAuraDataByAuraInstanceID
   (non-secret instance IDs only), on UNIT_AURA.
3. Blizzard's bars kept working but invisible ("set the actual bars to zero" = what it does): BuffBarCooldownViewer at alpha 0, moved
   off-screen (never hidden: a hidden viewer stops updating), mouse disabled, a SetPoint hook keeps it there (in combat only alpha, the
   move waits for PLAYER_REGEN_ENABLED). Icon viewers: the viewer stays an invisible shell; each Blizzard icon is re-anchored into the
   addon's own containers (not reparented).
4. Hooks used: OnCooldownIDSet on CooldownViewerBuffBarItemMixin / BuffIconItemMixin / EssentialItemMixin / UtilityItemMixin;
   EventRegistry CooldownViewerSettings.OnShow / OnHide; viewers' itemFramePool to enumerate items.
5. Taint care: hooksecurefunc / HookScript only; no fields written on Blizzard frames (separate weak tables); no reparenting; no hook
   on the viewers' Layout (it tainted); moves one frame late, outside Edit Mode's layout pass.
6. Edit Mode: once at login it sets HideWhenInactive on both buff viewers in the active layout and calls C_EditMode.SaveLayouts, then
   asks for a /reload (saving layouts at runtime taints Blizzard's isActive, so it is done only at login; a loop breaker stops repeat
   offers; preset layouts skipped).
7. "Custom buffs" typed by spell ID with a fixed duration are timed from UNIT_SPELLCAST_SUCCEEDED (not a real aura read).

## What it means for XayaUI (INFERENCE, for the proposal; nothing built)
- The "Enable tracking" button cannot be done safely by writing Blizzard's tracking list (the reference addon avoids it too; our own
  analysis said the same). The workable path is the one XayaUI already uses for debuffs: read the Cooldown Manager's own item state.
- B4 workaround: for an aura the player has put in Tracked Bars / Tracked Buffs, XayaUI can follow the Blizzard item (IsActive, the bar's
  value) and keep Blizzard's viewer invisible (alpha 0, off-screen, never hidden), so only XayaUI's cue shows. This still needs the player
  to track the aura in the Cooldown Manager once; the warning (B1) stays the way to tell her.
- Not done by the reference addon and not proposed: changing Edit Mode layouts at runtime.
