# ============================================================
#  DIJON Windows Setup Tool - Install Apps
#  Runs the whole "Important Apps" step under ONE clean progress
#  bar instead of pages of winget output.
#
#  - The current step is shown above the bar.
#  - Any failures are printed below the bar in red as they happen.
#  - winget's own chatter is captured to a variable so it does not
#    flood the screen.
#  - Exits with code 1 if anything failed, otherwise 0. The
#    launcher (bootstrap.ps1) reads that to decide the end screen.
#
#  This script assumes it is already running as administrator
#  (bootstrap.ps1, or install-apps.bat, guarantees that).
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference    = "Continue"

$failures = @()   # labels of steps that did not succeed

# ------------------------------------------------------------
#  Helpers
# ------------------------------------------------------------

# Install one winget package silently. Returns $true on success,
# and also treats "already installed / nothing to do" as success
# so re-running the tool doesn't show false failures.
function Install-App($id) {
    $out  = winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0) { return $true }

    $text = ($out | Out-String)
    if ($text -match 'already installed' -or
        $text -match 'No newer'          -or
        $text -match 'No applicable'     -or
        $text -match 'no available upgrade' -or
        $code -eq -1978335189) {
        return $true
    }
    return $false
}

# Copy the packaged wallpaper somewhere permanent and apply it live.
function Set-Wallpaper {
    $src = Join-Path $PSScriptRoot 'wallpaper.png'
    if (-not (Test-Path $src)) { return $false }

    $dst = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'dijon-wallpaper.png'
    Copy-Item $src $dst -Force -ErrorAction Stop

    # "Fill" fit mode
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value 10 -ErrorAction SilentlyContinue
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper  -Value 0  -ErrorAction SilentlyContinue

    Add-Type -MemberDefinition '[DllImport("user32.dll", SetLastError=true)] public static extern bool SystemParametersInfo(int a, int b, string c, int d);' -Name Wp -Namespace Win32 -ErrorAction SilentlyContinue
    [void][Win32.Wp]::SystemParametersInfo(20, 0, $dst, 3)
    return $true
}

# Copy each app's Start-Menu shortcut onto the Desktop. Best-effort:
# never fails the run, since the apps themselves are what matter.
function Set-Shortcuts {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $menus   = @([Environment]::GetFolderPath('CommonStartMenu'),
                 [Environment]::GetFolderPath('StartMenu'))
    foreach ($n in 'Discord','Steam','Riot Client','Logitech G HUB') {
        $lnk = Get-ChildItem $menus -Recurse -Filter *.lnk -ErrorAction SilentlyContinue |
               Where-Object { $_.BaseName -like "*$n*" } | Select-Object -First 1
        if ($lnk) {
            Copy-Item $lnk.FullName (Join-Path $desktop $lnk.Name) -Force -ErrorAction SilentlyContinue
        }
    }
    return $true
}

# ------------------------------------------------------------
#  Build the list of steps
# ------------------------------------------------------------
$steps = @(
    @{ Label = 'Setting desktop wallpaper';   Action = { Set-Wallpaper } }
    @{ Label = 'Installing Discord';          Action = { Install-App 'Discord.Discord' } }
    @{ Label = 'Installing Steam';            Action = { Install-App 'Valve.Steam' } }
    @{ Label = 'Installing Logitech G HUB';   Action = { Install-App 'Logitech.GHUB' } }
    @{ Label = 'Installing FACEIT Anti-Cheat';Action = { Install-App 'FACEITLTD.FACEITAC' } }
    @{ Label = 'Installing Riot Client';      Action = { Install-App 'RiotGames.Valorant.NA' } }
    @{ Label = 'Creating desktop shortcuts';  Action = { Set-Shortcuts } }
)

# If winget is missing, the app steps can't run. Say so once and drop
# them, but still do the wallpaper and (harmless) shortcut steps.
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "   winget was not found - app installs will be skipped." -ForegroundColor Red
    Write-Host "   Install 'App Installer' from the Microsoft Store to enable them." -ForegroundColor Red
    $failures += 'winget not available (apps skipped)'
    $steps = $steps | Where-Object { $_.Label -notlike 'Installing*' }
}

# ------------------------------------------------------------
#  Run the steps under a single progress bar
# ------------------------------------------------------------
$total = $steps.Count
$i     = 0

foreach ($step in $steps) {
    $i++
    $pct = [int]((($i - 1) / $total) * 100)
    Write-Progress -Activity "Installing important apps" `
                   -Status ("[{0}/{1}]  {2}" -f $i, $total, $step.Label) `
                   -PercentComplete $pct

    $ok = $false
    try { $ok = & $step.Action } catch { $ok = $false }

    if (-not $ok) {
        # Trim "Installing " / "Setting " etc. for a tidy failure label
        $short = $step.Label -replace '^(Installing|Setting|Creating)\s+', ''
        $failures += $short
        Write-Host ("   FAILED: {0}" -f $short) -ForegroundColor Red
    }
}

Write-Progress -Activity "Installing important apps" -Completed

# Signal the outcome to whoever launched us.
if ($failures.Count -gt 0) { exit 1 } else { exit 0 }
