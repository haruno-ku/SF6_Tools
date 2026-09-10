<#
.SYNOPSIS
    Sync this repo's REFramework payload into a Street Fighter 6 installation.

.DESCRIPTION
    Development installer for the SF6 Combo Explorer fork of Wael3rd/SF6_Tools.

    Copies the parts of the repo that belong in the game folder, and deliberately
    NEVER touches user-generated data (recorded combos, slot exports, session
    stats, per-user configs). Those live intermixed with the shipped data files
    under reframework/data, so the exclusion lists below are what keep a dev sync
    from destroying a training setup.

    dinput8.dll (REFramework itself) and reframework/plugins are first-run only:
    copied when absent, never overwritten, because replacing a loader the game
    already has is how you end up with a game that will not start. Pass
    -Bootstrap to install or refresh them deliberately.

.PARAMETER GameDir
    Street Fighter 6 install directory (the one holding StreetFighter6.exe).
    Defaults to $env:SF6_DIR, then the Steam library index, then known guesses.

.PARAMETER Bootstrap
    Also install dinput8.dll and reframework/plugins, overwriting if present.

.EXAMPLE
    .\scripts\install-dev.ps1 -WhatIf
    .\scripts\install-dev.ps1 -Bootstrap
    .\scripts\install-dev.ps1 -GameDir "D:\SteamLibrary\steamapps\common\StreetFighter6"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $GameDir,
    [switch] $Bootstrap
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

# --- locate the game ---------------------------------------------------------

function Find-GameDir {
    param([string] $Explicit)

    if ($Explicit)    { return $Explicit }
    if ($env:SF6_DIR) { return $env:SF6_DIR }

    $candidates = @()

    # Steam's own library index is the reliable source; guesses are the fallback.
    $steamRoots = @(
        (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath,
        (Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
    ) | Where-Object { $_ }

    foreach ($root in $steamRoots) {
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -ErrorAction SilentlyContinue) {
            foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) {
                $lib = $m.Groups[1].Value -replace '\\\\', '\'
                $candidates += (Join-Path $lib 'steamapps\common\StreetFighter6')
            }
        }
    }

    $candidates += @(
        'C:\Program Files (x86)\Steam\steamapps\common\StreetFighter6'
        'C:\SteamLibrary\steamapps\common\StreetFighter6'
        'D:\SteamLibrary\steamapps\common\StreetFighter6'
        'D:\Steam\steamapps\common\StreetFighter6'
        'E:\SteamLibrary\steamapps\common\StreetFighter6'
    )

    # -ErrorAction SilentlyContinue matters here: a candidate on a drive letter
    # that does not exist makes Test-Path raise "Cannot find drive", and the
    # script-wide Stop preference would turn that into a fatal error.
    foreach ($c in $candidates) {
        if (-not $c) { continue }
        $exe = Join-Path $c 'StreetFighter6.exe'
        if (Test-Path -LiteralPath $exe -ErrorAction SilentlyContinue) { return $c }
    }
    return $null
}

$GameDir = Find-GameDir -Explicit $GameDir
if (-not $GameDir) {
    throw "Street Fighter 6 not found. Pass -GameDir, or set the SF6_DIR environment variable to the folder holding StreetFighter6.exe."
}
if (-not (Test-Path (Join-Path $GameDir 'StreetFighter6.exe'))) {
    throw "No StreetFighter6.exe in '$GameDir' - that is not the game folder."
}

# REFramework loads these at startup and holds the DLLs open, so syncing over a
# live game is either a silent no-op or a corrupt half-write.
if (Get-Process -Name 'StreetFighter6' -ErrorAction SilentlyContinue) {
    throw 'Street Fighter 6 is running. Close it before syncing.'
}

Write-Host "repo : $RepoRoot"
Write-Host "game : $GameDir"
Write-Host ''

# --- what a dev sync must never clobber --------------------------------------

# Directory names for robocopy /XD. Everything here is produced by the mod at
# runtime and sits alongside the shipped data files.
$ExcludeDirs = @(
    'CustomCombos'                  # user-recorded combo trials
    'ReplayRecords'                 # raw input recordings
    'Stats'                         # session statistics
    'Backups'                       # RSM pre-import slot backups
    'SF6_RecordingSlotManager_data' # per-character slot exports

    # Combo Explorer output. These are produced on THIS machine and travel the
    # other way - written here, copied into the repo, committed, read on the dev
    # machine. Syncing them repo -> game would overwrite a fresh probe result
    # with whatever was last committed, which is silent data loss in exactly the
    # workflow they exist for.
    'diagnostics'
    'calibration'
    'catalog'
    'results'
)

# Per-user config written by the mod. Shipping our copies would reset the user's
# language, hotkeys, colours and toggles on every sync.
$ExcludeFiles = @(
    'UILang_Config.json'
    'TrainingHotkeys_Config.json'
    'TrainingManager_Config.json'
    'SF6DistanceViewer_Config.json'
    'SF6DistanceLogger_Config.json'
    'SheldonsBoxes_Config.json'
    'TrainingHitConfirm_Config.json'
    'TrainingPostGuard_Config.json'
    'TrainingReactions_Config.json'
    'CommandLogger_Visualizer.json'
    'XT_Settings.json'
    'CompletedTrials.json'
)

function Sync-Tree {
    param([string] $Source, [string] $Dest, [string] $Label)

    if (-not (Test-Path $Source)) { Write-Host "skip  $Label (not in repo)"; return }

    $rcArgs = @($Source, $Dest, '/E', '/NJH', '/NJS', '/NP', '/NDL', '/R:2', '/W:1')
    if ($ExcludeDirs.Count)  { $rcArgs += '/XD'; $rcArgs += $ExcludeDirs }
    if ($ExcludeFiles.Count) { $rcArgs += '/XF'; $rcArgs += $ExcludeFiles }
    if ($WhatIfPreference)   { $rcArgs += '/L' }

    Write-Host "sync  $Label"
    & robocopy @rcArgs | Where-Object { $_ -match '\S' } | ForEach-Object { "      $_" }

    # robocopy exit codes 0-7 are success (1 = files were copied); 8+ are failures.
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed for $Label (exit $LASTEXITCODE)" }
    $global:LASTEXITCODE = 0
}

# --- the payload -------------------------------------------------------------

Sync-Tree (Join-Path $RepoRoot 'reframework\autorun') (Join-Path $GameDir 'reframework\autorun') 'reframework/autorun'
Sync-Tree (Join-Path $RepoRoot 'reframework\data')    (Join-Path $GameDir 'reframework\data')    'reframework/data'
Sync-Tree (Join-Path $RepoRoot 'reframework\fonts')   (Join-Path $GameDir 'reframework\fonts')   'reframework/fonts'
Sync-Tree (Join-Path $RepoRoot 'reframework\images')  (Join-Path $GameDir 'reframework\images')  'reframework/images'

# --- first-run only: REFramework loader and native plugins -------------------

function Install-Once {
    param([string] $Source, [string] $Dest, [string] $Label)

    if (-not (Test-Path $Source)) { Write-Host "skip  $Label (not in repo)"; return }

    $exists = Test-Path $Dest
    if ($exists -and -not $Bootstrap) {
        Write-Host "keep  $Label (already installed; -Bootstrap to overwrite)"
        return
    }
    if ($PSCmdlet.ShouldProcess($Dest, 'install')) {
        $parent = Split-Path -Parent $Dest
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force $parent | Out-Null }
        Copy-Item $Source $Dest -Force -Recurse
        $verb = if ($exists) { 'over' } else { 'new ' }
        Write-Host "$verb  $Label"
    }
}

Install-Once (Join-Path $RepoRoot 'dinput8.dll') (Join-Path $GameDir 'dinput8.dll') 'dinput8.dll (REFramework)'

$pluginSrc = Join-Path $RepoRoot 'reframework\plugins'
if (Test-Path $pluginSrc) {
    foreach ($dll in Get-ChildItem $pluginSrc -Filter *.dll) {
        Install-Once $dll.FullName (Join-Path $GameDir "reframework\plugins\$($dll.Name)") "plugins/$($dll.Name)"
    }
}

Write-Host ''
if ($WhatIfPreference) {
    Write-Host 'dry run - nothing was written.'
} else {
    Write-Host 'done. Launch SF6 and press Insert to open the REFramework menu.'
}
