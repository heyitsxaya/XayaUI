# Right-click and dropdown menus in the XayaUI look (Reskin 0.6.12, Dev Assist 0.7.43)

Logged 2026-11-07 12:52 UTC. Session 014bN6tSvVzc2HRgXhwF3J2L (reskin successor), branch `claude/determined-cerf-981pn8`. Request rows
RESKIN-3 ("menus") and RESKIN-4 (Q12 "all"). Item 3 of the unbuilt list in `docs/process/handoffs/reskin-elements.md`.

## What changed
- `XayaUI_Reskin/BlizzardSkins.lua`: new page **Menus** (key `rskmenus`, saved `CueRulesDB.ui.rsk.menus`), off until ticked.
  - When ticked (and only then) a `hooksecurefunc` post-hook is placed on `MenuStyle1Mixin.Generate`. Each time Blizzard builds a menu,
    the hook finds the menu's own background texture (atlas `common-dropdown-bg`) among the menu frame's regions and recolours it to the
    theme's window colour (`SetColorTexture`) at Background opacity (`SetAlpha`).
  - Nothing is added to Blizzard's pooled menu frame (no texture, frame, script or anchor of ours); entries and clicks are Blizzard's.
    This follows the Esc-menu lesson (GameMenuSkin.lua header): act each time Blizzard builds, never keep state on pooled parts.
  - Off: the hook stays until /reload and does nothing; Blizzard sets its atlas and alpha on every build, so the next menu is its own.
  - Every region read is guarded with pcall (`GetRegions` carries SecretReturnsForAspect Hierarchy; a secret menu is left alone).
- Choices made without her (to the QA flow): background only, no 1 px border (a border would mean adding textures to Blizzard's pooled
  menu frames); Blizzard's own background rectangle is kept (it reaches 10 px past the menu's sides and 3 px above / below, so the solid
  colour does too). Alternative: our own border frame drawn around each open menu.
- `XayaUI_DevAssist/QAWalks-reskin.lua`: walkthrough "Reskin: right-click and dropdown menus" (prefill). A menu closes when Check is
  clicked, so the check reads a count of menus painted since the walkthrough switched the page on (`diag.menus`).
- QA-CHECKLIST G11, G8 lists `menus`. Page-list tests (reskin_tab, reskin_tab_switch, sidebar_switches) list the new page.

## Scope (V4)
- `git grep MenuStyle1Mixin\|Blizzard_Menu`: no other XayaUI file hooks Blizzard's menu style.
- Other menu styles (MenuStyle2Mixin: character customization only; the green test style) are not hooked.
- A mixin made from MenuStyle1Mixin before our hook is placed would not carry it (none found in 12.1.5 Mainline).

## V2 (source / API)
- 12.1.5 (Gethe/wow-ui-source 297d7aa, read as data, nothing copied): `Blizzard_Menu/Menu.lua:2094-2135` (SecureGenerate: `Mixin(proxy,
  menuMixin)` then `proxy:Generate()`, on each AcquireMenu), `Mainline/MenuVariants.lua:1-7` (MenuStyle1Mixin is the default for menus
  and context menus), `Mainline/MenuTemplates.lua:51-61` (Generate attaches the background, atlas `common-dropdown-bg`, alpha 0.925).
- `widgets.md`: `GetAtlas()` (SimpleTextureBaseAPI); `SetColorTexture` ChecksForbiddenAspects SetTexture, SecretArguments
  AllowedWhenTainted; `GetRegions()` SecretReturnsForAspect Hierarchy.
- INFERENCE (not verifiable here): that a hooksecurefunc post-hook on a mixin method copied into the menu inside securecallfunction
  leaves the menu's secure entries working. It is the same mechanism as the tooltip skin's hook. The walkthrough's step 3 asks her to
  use menu entries and watch for errors.

## Tests
- `tests/reskin_blizzard_skins_run.py`: 73 checks (8 new). On the old code `BS.MenusPage` is nil (the run stops).
- `tests/qa_walks_reskin_run.py`: 36 checks (6 new).

## Not verified in game
All of it, and the taint question above is the main risk.
