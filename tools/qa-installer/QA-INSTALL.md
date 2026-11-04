# Installing and updating XayaUI with GitHub Desktop (testers)

This file is for the `qa-installer-branch` branch. That branch is an automatic copy of `main` (same files, same version) with this installer added. **Do not commit to it**; anything you change there is replaced on the next sync.

## Why a plain clone does not work

The game only loads an addon when its folder sits directly inside `Interface\AddOns` (`AddOns\XayaUI\XayaUI.toc`, `AddOns\XayaUI_Chat\XayaUI_Chat.toc`, and so on). A GitHub Desktop clone is one folder that *contains* all the XayaUI folders, so cloning it into `AddOns` puts them one level too deep (`AddOns\XayaUI\XayaUI_Chat\...`) and the game loads nothing. The installer below fixes that once; after that, updating is only a pull.

## One-time setup (about 5 minutes)

1. **Close the game** completely.
2. **If you already cloned XayaUI into the game's AddOns folder**, undo that first: in GitHub Desktop choose **Repository > Remove**, then delete that folder (for example `...\Interface\AddOns\XayaUI`). Your settings are stored elsewhere (`WTF\...\SavedVariables`) and are not affected.
3. In GitHub Desktop choose **File > Clone repository > URL**, enter `heyitsxaya/XayaUI`, and set **Local path** to a folder **outside the game and outside any cloud-synced folder**, for example `C:\GitHub\XayaUI`. Click **Clone**.
4. Click **Current branch** and choose **`qa-installer-branch`** (type "qa" to find it).
5. Choose **Repository > Show in Explorer**, then double-click **`Install-XayaUI.bat`**.
   - If Windows shows "Windows protected your PC", choose **More info > Run anyway**.
   - It finds your game folder, lists what it will do, and asks **Go ahead? [Y/n]**. Press Enter.
   - Windows may ask for administrator rights (the game folder is under Program Files); choose **Yes**.
   - **Expect:** a green `OK` line for each of `XayaUI`, `XayaUI_Bonus`, `XayaUI_Chat`, `XayaUI_Media`, `XayaUI_Options`, `XayaUI_QoL`, and `XayaUI_Reskin`, then `Done.`
   - Anything it had to move out of the way (an older manual copy, an old checkout) is moved, not deleted, to `Interface\XayaUI-backup-<date-time>`.
6. Start the game and follow `QA-CHECKLIST.md` from section A3.

To see what the installer would do without changing anything, run it from a command window as `Install-XayaUI.bat -DryRun`.

## Updating to a new build

1. In GitHub Desktop (with `qa-installer-branch` selected): **Fetch origin**, then **Pull origin**. The game can stay open.
2. In the game, type `/reload`. That is all it takes; the game does not need to be restarted.

You do not need to run the installer again unless the release note says a new `XayaUI_*` folder was added. Running it again is always safe.

## If the installer stops with a red error

Use the simple installer instead: in `tools\qa-installer\` (or the top folder on `qa-installer-branch`), right-click **`Link-XayaUI.bat`** and choose **Run as administrator**. It does the same linking with plain Windows commands (no PowerShell), works on any branch, moves real folders in the way to `Interface\XayaUI-backup-<number>`, and leaves `XayaUI_GameDump` alone. If your game is not in `C:\Program Files (x86)\World of Warcraft`, run it from a command window with your AddOns folder in quotes after the file name.

## If something is off

| What you see | What to do |
|---|---|
| The AddOns list shows no XayaUI at all | Run `Install-XayaUI.bat` again and look for a red `FAIL` line. |
| "Missing dependency" on an XayaUI addon | The core `XayaUI` folder is not linked. Run `Install-XayaUI.bat` again. |
| The installer says the checkout is inside AddOns | Follow step 2 above, then clone again outside the game folder. |
| The installer says the game is running | Close the game (check Task Manager for `Wow.exe`), then run it again. |
| You want it all gone | Double-click `Uninstall-XayaUI.bat`. It removes only the links; your checkout, settings, and other addons stay. |

When you report a problem, please include: the build number shown in the installer's first line (or the `Version` line in `XayaUI\XayaUI.toc`), a screenshot of the installer window, and the `/xui status` output if the game starts.
