# Bar textures: no duplicates, the game's power-bar art, XayaUI's bar fills (core 0.6.53 / Options 0.6.51, not on main)
Logged 2026-11-06 20:18 UTC. Session 014bN6tX7AoZQrGX246YSXjC, branch `claude/dreamy-edison-pvb3i1`. Not run in game (QA B179).

## Request (Xaya, 2026-11-06, her words; REQUEST-LOG S8-11, S8-12)
- "check elvui, wa, and eui folders -- most of them have multiple bar display options"; after the check: "Fix duplicates", "Add
  Blizzard power-bar art", "Add XayaUI's own bar art" (not chosen: reading EllesmereUI's private list).

## Reference check (read-only, Drive "Reference Addons (REFERENCE AND READ ONLY)"; behaviour only, nothing copied, our implementation is independent)
- ElvUI: 6 statusbar textures of its own, registered with LibSharedMedia. WeakAuras: 4 of its own, registered with LibSharedMedia, plus
  game power-bar atlases under its own "statusbar_atlas" type. EllesmereUI: 21 of its own, NOT registered with LibSharedMedia (in
  EllesmereUI.lua; its other files were not scanned), and game power-bar atlases for resource bars. Every bundled LibSharedMedia adds
  4 game files to "statusbar" (Blizzard, Blizzard Character Skills Bar, Blizzard Raid Bar, Solid): three are XayaUI's own Flat /
  Blizzard / Raid frame, so they showed twice.

## Change (`XayaUI/BarCue.lua`)
- `ns.BarTextureList`: a texture already listed (same file, slashes and case ignored) is not listed again.
- `ns.BarBlizzardAtlases`: the game's power-bar art read at run time from Blizzard's own `PowerBarColor` table
  (Blizzard_UnitFrame/Mainline/PowerBarColorUtil.lua, 12.1.5): `atlas`, or for `atlasElementName` the player frame's name
  "UI-HUD-UnitFrame-Player-PortraitOn-Bar-<element>" (UnitFrame.lua, AlternatePowerBarBase.lua), plus the player frame's health bar;
  an atlas `C_Texture.GetAtlasInfo` does not know is left out. Listed as "Blizzard power: <Name>", key "atlas:<atlas>";
  `ns.BarTexturePath` hands the atlas name to SetStatusBarTexture, as Blizzard's unit frames do (also in the engine's bars).
- `ns.BarXayaFills`: the "[Bar Fills]" entries of LocalGraphics.lua whose name is a fill ("_Fill", "-fill", "BarHorizontal"; not
  sparks, frames, backgrounds, flashes); listed as "XayaUI: <name>", key "gfx:<path>"; `ns.BarRegisterLSM` registers them once at
  login as LibSharedMedia "statusbar" "XayaUI <name>" (only when some addon has loaded LibSharedMedia).
- `XayaUI_Options/Options.lua`: the Bar texture list's tooltip says where the entries come from and that coloured art is tinted.

## Decisions (mine; for Xaya)
1. Labels "Blizzard power: <Name>" and "XayaUI: <name>" (file names as they are).
2. The bar colour tints coloured art (no new switch); Colour = Fixed white shows the art as drawn.
3. XayaUI's fills are registered with LibSharedMedia even though the public download lacks the files (#333): on such an install
   other addons list XayaUI entries that draw nothing. Alternative if she prefers: register only from her own install / after #333.

## Tests
- `tests/bar_cue_run.py`: 100 checks, 0 failed (+9): fills registered (fills only); no second Blizzard / Solid / Raid bar; XayaUI's
  registered fill listed once; other addons' textures kept; power art from the table (full atlas, element name, health); unknown
  atlas left out; spark not offered; texture paths for atlas and fill keys. On the previous BarCue.lua: the run errors at the first
  new check. `lua_pitfalls_run.py` FAILS: 0.

## Not verified
- In game: that SetStatusBarTexture with these atlas names draws them stretched as a bar fill in our StatusBar (Blizzard's own unit
  frames do exactly this, so INFERENCE: yes); which XayaUI fill files exist on her install.

## Update 2026-11-06 20:47 UTC: XayaUI's own fills taken out (REQUEST-LOG S8-13)
Xaya (question box), on sharing the fills: "if these are the addon's own options, these should be treated as a roadmap feature that
require their own design solves -- punt them out for now and just leave a scaffold note that it will be live later". So:
`ns.BarXayaFills`, `ns.BarRegisterLSM` and its login hook, the "gfx:" list entries and texture keys are removed; `BarCue.lua` keeps a
"SCAFFOLD, NOT LIVE" note; ROADMAP RM-BARFILLS holds the design questions. Decision 3 above is moot. The duplicate fix and the game's
power-bar art stay. `tests/bar_cue_run.py`: 98 checks, 0 failed; its two new checks ("not live": nothing registered, no "XayaUI:"
entry) fail on 9758ee0's BarCue.lua.
