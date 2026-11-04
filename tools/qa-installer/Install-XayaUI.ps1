<#
.SYNOPSIS
  Links the XayaUI addon folders from this GitHub Desktop checkout into World of Warcraft\_retail_\Interface\AddOns.

.DESCRIPTION
  The game only loads an addon when its folder sits directly inside Interface\AddOns (AddOns\XayaUI\XayaUI.toc,
  AddOns\XayaUI_Chat\XayaUI_Chat.toc, and so on). A GitHub Desktop checkout is one folder that CONTAINS all of those
  folders, so it cannot be cloned into AddOns directly. This script makes a Windows folder link (a "junction") in AddOns
  for each addon folder in the checkout. A junction needs no administrator rights on the same machine in the normal case,
  and the game reads it like a normal folder. After that, a plain GitHub Desktop "Pull origin" updates the game files.

  Safe to run again at any time (it only fixes what is missing or wrong). Run it again after a pull that adds a new
  XayaUI_* folder; the release note for that build says so.

  Real folders it finds in the way (an older manual copy, an old checkout) are MOVED to
  Interface\XayaUI-backup-<date-time>, never deleted. Your settings (WTF\...\SavedVariables) are never touched.

.PARAMETER AddOnsPath
  The Interface\AddOns folder. Found automatically when omitted; you are asked if it cannot be found.
.PARAMETER Remove
  Removes the links this script made (real folders and other addons are never touched).
.PARAMETER DryRun
  Shows what would happen and changes nothing.
.PARAMETER Yes
  Do not ask for confirmation.
.PARAMETER IncludeGameDump
  Also link XayaUI_GameDump (a debugging tool; not needed to play or test).
.PARAMETER PauseAtEnd
  Wait for Enter before closing (used when this script re-launches itself as administrator).
#>
[CmdletBinding()]
param(
    [string]$AddOnsPath,
    [switch]$Remove,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$IncludeGameDump,
    [switch]$PauseAtEnd
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

function Say([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

function Finish([int]$Code) {
    if ($PauseAtEnd) { Read-Host 'Press Enter to close' | Out-Null }
    exit $Code
}

function Fail([string]$Text) {
    Say ''
    Say ('STOPPED: ' + $Text) 'Red'
    Finish 1
}

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-SamePath([string]$A, [string]$B) {
    if (-not $A -or -not $B) { return $false }
    $A = $A -replace '^\\\?\?\\', ''
    $B = $B -replace '^\\\?\?\\', ''
    return ((Get-FullPath $A) -ieq (Get-FullPath $B))
}

function Find-AddOnsFolders {
    $cands = New-Object 'System.Collections.Generic.List[string]'
    foreach ($key in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft', 'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
        try {
            $ip = (Get-ItemProperty -LiteralPath $key -ErrorAction Stop).InstallPath
            if ($ip) {
                $cands.Add((Join-Path $ip 'Interface\AddOns'))
                $cands.Add((Join-Path $ip '_retail_\Interface\AddOns'))
            }
        } catch { }
    }
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -ne 'Fixed') { continue }
        foreach ($rel in 'Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft', 'World of Warcraft', 'Games\World of Warcraft') {
            $cands.Add((Join-Path $drive.Name ($rel + '\_retail_\Interface\AddOns')))
        }
    }
    $found = @()
    foreach ($c in $cands) {
        if (Test-Path -LiteralPath $c -PathType Container) {
            $full = Get-FullPath $c
            if (-not ($found -contains $full)) { $found += $full }
        }
    }
    return $found
}

function Test-AddOnsFolder([string]$Path) {
    if (-not $Path) { return $false }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    return ((Split-Path -Leaf (Get-FullPath $Path)) -ieq 'AddOns')
}

function Get-LinkTarget($Item) {
    if (-not ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { return $null }
    $t = $null
    try { $t = $Item.Target } catch { }
    if ($t -is [array]) { $t = $t[0] }
    return $t
}

function New-Junction([string]$Link, [string]$Source) {
    try {
        New-Item -ItemType Junction -Path $Link -Value $Source | Out-Null
    } catch {
        $msg = $_.Exception.Message
        $out = & cmd.exe /c ('mklink /J "{0}" "{1}"' -f $Link, $Source) 2>&1
        if ($LASTEXITCODE -ne 0) { throw ('{0} ({1})' -f $msg, ($out -join ' ')) }
    }
}

# Any unexpected error: say where it happened (2026-11-04: Xaya got "You cannot call a method on a null-valued expression" with no
# line number, right after the AddOns line), so the next report points at the exact line.
trap {
    Say ''
    Say ('STOPPED: ' + $_.Exception.Message) 'Red'
    if ($_.InvocationInfo) { Say ('Where: ' + $_.InvocationInfo.PositionMessage) 'Red' }
    if ($_.ScriptStackTrace) { Say $_.ScriptStackTrace 'DarkGray' }
    Say 'Send a screenshot of this window. Link-XayaUI.bat (right-click, Run as administrator) does the same job without PowerShell.' 'Yellow'
    Finish 1
}

# ---------------------------------------------------------------- find the checkout and its addon folders
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'XayaUI\XayaUI.toc'))) {
    Fail ('This script must stay in the top folder of the XayaUI checkout, next to the XayaUI folder. It is in: ' + $RepoRoot)
}
$RepoFull = Get-FullPath $RepoRoot

$addons = @(Get-ChildItem -LiteralPath $RepoRoot -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName ($_.Name + '.toc')) } |
    Where-Object { $IncludeGameDump -or $_.Name -ne 'XayaUI_GameDump' } |
    Sort-Object Name)
if ($addons.Count -eq 0) { Fail 'No addon folders (a folder holding a .toc file with the same name) were found next to this script.' }

$version = ''
try {
    $line = Select-String -LiteralPath (Join-Path $RepoRoot 'XayaUI\XayaUI.toc') -Pattern '^##\s*Version:\s*(.+)$' | Select-Object -First 1
    if ($line) { $version = $line.Matches[0].Groups[1].Value.Trim() }
} catch { }

Say ''
Say ('XayaUI QA install' + $(if ($version) { ' - build ' + $version } else { '' })) 'Cyan'
Say ('Checkout : ' + $RepoFull)

# ---------------------------------------------------------------- find the game's AddOns folder
if ($AddOnsPath) {
    if (-not (Test-AddOnsFolder $AddOnsPath)) { Fail ('That is not an existing folder named AddOns: ' + $AddOnsPath) }
    $AddOns = Get-FullPath $AddOnsPath
} else {
    $found = @(Find-AddOnsFolders)
    if ($found.Count -eq 1) {
        $AddOns = $found[0]
    } else {
        if ($found.Count -gt 1) {
            Say 'More than one World of Warcraft AddOns folder was found:' 'Yellow'
            for ($i = 0; $i -lt $found.Count; $i++) { Say ('  {0}) {1}' -f ($i + 1), $found[$i]) }
            $pick = Read-Host 'Type the number of the one you play retail from'
            $n = 0
            if ([int]::TryParse($pick, [ref]$n) -and $n -ge 1 -and $n -le $found.Count) { $AddOns = $found[$n - 1] }
        }
        if (-not $AddOns) {
            Say 'The AddOns folder was not found automatically.' 'Yellow'
            $typed = (Read-Host 'Paste the full path of your ...\_retail_\Interface\AddOns folder').Trim().Trim('"')
            if (-not (Test-AddOnsFolder $typed)) { Fail ('That is not an existing folder named AddOns: ' + $typed) }
            $AddOns = Get-FullPath $typed
        }
    }
}
Say ('AddOns   : ' + $AddOns)

if ($RepoFull.StartsWith($AddOns + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    Fail ("This checkout is inside the game's AddOns folder, and the game cannot load addons from inside another folder.`n" +
          "Fix: in GitHub Desktop choose Repository > Remove (keep the files if asked), delete the folder " + $RepoFull + ",`n" +
          "then File > Clone repository, pick heyitsxaya/XayaUI, set the Local path to a folder OUTSIDE the game (for example C:\GitHub\XayaUI),`n" +
          "and after cloning switch to the qa-installer-branch branch. Then double-click Install-XayaUI.bat in the new folder.")
}
if ($RepoFull -match '(?i)OneDrive|My Drive|Google Drive|Dropbox') {
    Say 'WARNING: this checkout is in a cloud-synced folder. Cloud sync can leave placeholder files the game cannot read.' 'Yellow'
    Say '         A plain local folder such as C:\GitHub\XayaUI is safer.' 'Yellow'
}

# The game may stay open: like any addon install, the new folders are picked up by a /reload in game (Xaya, 2026-11-04:
# "whenever I download an addon from curseforge, I don't close the game; I just reload after it installs").

# ---------------------------------------------------------------- what is in AddOns now
$existing = @{}
foreach ($item in (Get-ChildItem -LiteralPath $AddOns -Force -Directory -ErrorAction SilentlyContinue)) { $existing[$item.Name.ToLowerInvariant()] = $item }

$names = @($addons | ForEach-Object { $_.Name })
$legacy = @('XayaUI_CombatEngine')   # folded into XayaUI in 0.6.0; a leftover copy would double-track

# ---------------------------------------------------------------- remove mode
if ($Remove) {
    Say ''
    foreach ($name in $names) {
        $item = $existing[$name.ToLowerInvariant()]
        if (-not $item) { Say ('  --   ' + $name + ' (not present)'); continue }
        $target = Get-LinkTarget $item
        if ($target -and (Test-SamePath $target (Join-Path $RepoFull $name))) {
            if ($DryRun) { Say ('  would remove link ' + $name) 'Yellow' }
            else { [System.IO.Directory]::Delete($item.FullName); Say ('  removed link ' + $name) 'Green' }
        } else {
            Say ('  left   ' + $name + ' (not a link to this checkout, so not touched)') 'Yellow'
        }
    }
    Say ''
    Say 'Done. Your settings were not touched.' 'Green'
    Finish 0
}

# ---------------------------------------------------------------- plan
$plan = @()
foreach ($name in ($names + $legacy)) {
    $isLegacy = ($legacy -contains $name) -and -not ($names -contains $name)
    $item = $existing[$name.ToLowerInvariant()]
    $source = Join-Path $RepoFull $name
    $action = ''
    if ($isLegacy) {
        if ($item -and -not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { $action = 'backup-legacy' }
    } elseif (-not $item) {
        $action = 'link'
    } else {
        $target = Get-LinkTarget $item
        if ($target) {
            if (Test-SamePath $target $source) { $action = 'ok' } else { $action = 'relink' }
        } else {
            $action = 'backup-link'
        }
    }
    if ($action) { $plan += [pscustomobject]@{ Name = $name; Action = $action; Source = $source; Item = $item } }
}

Say ''
foreach ($p in $plan) {
    switch ($p.Action) {
        'ok'            { Say ('  ok       ' + $p.Name + ' (already linked)') }
        'link'          { Say ('  link     ' + $p.Name) 'Cyan' }
        'relink'        { Say ('  relink   ' + $p.Name + ' (points somewhere else now)') 'Yellow' }
        'backup-link'   { Say ('  backup   ' + $p.Name + ' (a real folder is in the way; it is moved to the backup folder, then linked)') 'Yellow' }
        'backup-legacy' { Say ('  backup   ' + $p.Name + ' (old folder, no longer used; moved to the backup folder)') 'Yellow' }
    }
}
$changes = @($plan | Where-Object { $_.Action -ne 'ok' })
if ($changes.Count -eq 0) {
    Say ''
    Say 'Everything is already linked. Nothing to do.' 'Green'
    Finish 0
}
if ($DryRun) { Say ''; Say 'Dry run: nothing was changed.' 'Yellow'; Finish 0 }

if (-not $Yes) {
    Say ''
    $answer = Read-Host 'Go ahead? [Y/n]'
    if ($answer -and $answer.Trim().ToLowerInvariant() -notin 'y', 'yes') { Say 'Cancelled. Nothing was changed.' 'Yellow'; Finish 0 }
}

# ---------------------------------------------------------------- apply
$interface = Split-Path -Parent $AddOns
$backupRoot = Join-Path $interface ('XayaUI-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$backedUp = @()
try {
    foreach ($p in $changes) {
        $link = Join-Path $AddOns $p.Name
        switch ($p.Action) {
            'relink' {
                [System.IO.Directory]::Delete($link)
                New-Junction $link $p.Source
            }
            'link' {
                New-Junction $link $p.Source
            }
            { $_ -in 'backup-link', 'backup-legacy' } {
                if (-not (Test-Path -LiteralPath $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot | Out-Null }
                $dest = Join-Path $backupRoot $p.Name
                Move-Item -LiteralPath $link -Destination $dest
                $backedUp += $p.Name
                if ($p.Action -eq 'backup-link') { New-Junction $link $p.Source }
            }
        }
    }
} catch {
    $msg = $_.Exception.Message
    if (($msg -match 'denied|not permitted|privilege') -and -not (Test-IsAdmin)) {
        Say ''
        Say 'Windows wants administrator rights to change this folder. Asking now (click Yes on the Windows prompt)...' 'Yellow'
        $argList = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -AddOnsPath "{1}" -Yes -PauseAtEnd' -f $PSCommandPath, $AddOns
        if ($IncludeGameDump) { $argList += ' -IncludeGameDump' }
        try {
            Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait
            Say 'The administrator window has finished. Run this script once more with -DryRun if you want to see the final state.' 'Gray'
            Finish 0
        } catch {
            Fail 'Administrator rights were not granted. Right-click Install-XayaUI.bat and choose "Run as administrator".'
        }
    }
    Fail ('Something went wrong: ' + $msg)
}

# ---------------------------------------------------------------- verify
Say ''
Say 'Checking the result:' 'Cyan'
$bad = 0
foreach ($name in $names) {
    $link = Join-Path $AddOns $name
    $item = Get-ChildItem -LiteralPath $AddOns -Force -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    $target = $null
    if ($item) { $target = Get-LinkTarget $item }
    $tocOk = Test-Path -LiteralPath (Join-Path $link ($name + '.toc'))
    $isLink = ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint))
    if ($isLink -and $tocOk -and ((-not $target) -or (Test-SamePath $target (Join-Path $RepoFull $name)))) {
        Say ('  OK   {0}\{0}.toc is readable through the link' -f $name) 'Green'
    } else {
        Say ('  FAIL {0}' -f $name) 'Red'
        $bad++
    }
}
if ($backedUp.Count -gt 0) {
    Say ''
    Say ('Moved out of the way (nothing was deleted): ' + ($backedUp -join ', ')) 'Yellow'
    Say ('They are in: ' + $backupRoot) 'Yellow'
    Say 'If one of them was an old GitHub Desktop checkout, remove it from GitHub Desktop (Repository > Remove) so it stops showing an error.' 'Yellow'
}
Say ''
if ($bad -gt 0) { Say ('{0} folder(s) did not link correctly. Send a screenshot of this window.' -f $bad) 'Red'; Finish 1 }
Say 'Done. Start the game; new folders need a full restart, not just /reload.' 'Green'
Say 'To update later: GitHub Desktop > Fetch origin > Pull origin. No need to run this again unless told to.' 'Gray'
Finish 0
