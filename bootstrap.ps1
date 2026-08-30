# ============================================================
#  DIJON PC CLEANUP TOOL - Bootstrap
#  Shows a menu, then downloads and runs the chosen setup(s).
#  You can pick several at once, separated by commas (e.g. 1,2,4).
#
#  Admin is requested ONCE at launch, so the tasks then run
#  back-to-back with no further prompts.
#
#  EDIT THE TWO LINES BELOW if your repo details change.
# ============================================================

$GitHubUser = "dijon4"
$RepoName   = "lan"

# ------------------------------------------------------------

$ErrorActionPreference = "Stop"

# ============================================================
#  STEP 0 - Get administrator rights ONCE, up front.
#  If we aren't admin yet, relaunch this same command in an
#  elevated window and let that copy do the work. That single
#  approval covers every task, so nothing below ever prompts
#  again.
# ============================================================
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "  Requesting administrator rights (one time)..." -ForegroundColor Cyan
    try {
        $relaunch = "irm https://raw.githubusercontent.com/$GitHubUser/$RepoName/main/bootstrap.ps1 | iex"
        Start-Process powershell -Verb RunAs -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $relaunch
        )
    }
    catch {
        Write-Host ""
        Write-Host "  Admin rights are required. Approve the prompt and run it again." -ForegroundColor Yellow
        Write-Host ""
    }
    return
}

# Each menu number maps to the .bat file it runs. Order here = order shown.
$OptionMap = [ordered]@{
    "1" = @{ Name = "Setup NVIDIA + performance settings";           Bat = "tournament-setup.bat" }
    "2" = @{ Name = "Windows 11 Cleanup (Default)";                  Bat = "run-win11debloat.bat" }
    "3" = @{ Name = "Windows 11 Cleanup (Custom)";                   Bat = "run-win11debloat-custom.bat" }
    "4" = @{ Name = "Install apps (Discord, Steam, Logitech G HUB)"; Bat = "install-apps.bat" }
}

function Show-Menu {
    Write-Host ""
    Write-Host "  +----------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |     LAUNCHED DIJON PC CLEANUP TOOL     |" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    foreach ($key in $OptionMap.Keys) {
        Write-Host ("   {0}. {1}" -f $key, $OptionMap[$key].Name)
    }
    Write-Host "   Q. Quit"
    Write-Host ""
    Write-Host "   Tip: choose several at once, separated by commas (e.g. 1,2,4)" -ForegroundColor DarkGray
    Write-Host ""
}

# --- Ask until we get one or more valid options ---
$selected = @()
while ($selected.Count -eq 0) {
    Show-Menu
    $choice = Read-Host "  Select option(s)"

    $trimmed = $choice.Trim().ToUpper()
    if ($trimmed -eq "Q") {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        return
    }

    $picked     = @()   # chosen option objects, in the order typed
    $pickedBats = @()   # their bat names, used to skip duplicates
    $bad        = @()   # anything that wasn't a valid option

    foreach ($part in $trimmed.Split(",")) {
        $p = $part.Trim()
        if ($p -eq "") { continue }
        if ($OptionMap.Contains($p)) {
            $opt = $OptionMap[$p]
            if ($pickedBats -notcontains $opt.Bat) {
                $picked     += $opt
                $pickedBats += $opt.Bat
            }
        } else {
            $bad += $p
        }
    }

    if ($bad.Count -gt 0) {
        Write-Host ""
        Write-Host ("  Not valid: {0}. Enter numbers 1-4 (e.g. 1,2,4) or Q." -f ($bad -join ", ")) -ForegroundColor Yellow
    }
    elseif ($picked.Count -eq 0) {
        Write-Host ""
        Write-Host "  Nothing entered. Enter numbers 1-4 (e.g. 1,2,4) or Q." -ForegroundColor Yellow
    }
    else {
        $selected = $picked
    }
}

# --- Download the package once ---
$zipUrl  = "https://github.com/$GitHubUser/$RepoName/archive/refs/heads/main.zip"
$workDir = Join-Path $env:TEMP "dijon-cleanup"
$zipPath = Join-Path $env:TEMP "dijon-pkg.zip"

try {
    Write-Host ""
    Write-Host "  Downloading package..." -ForegroundColor Cyan

    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
    New-Item -ItemType Directory -Path $workDir | Out-Null

    $ProgressPreference = "Continue"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "  Extracting..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force

    # Clear the "downloaded from internet" flag so the files will run
    Get-ChildItem $workDir -Recurse | Unblock-File -ErrorAction SilentlyContinue

    # ============================================================
    #  Run each chosen task, one at a time, in the order picked.
    #  We are already admin, so these run inline with no prompts,
    #  and a progress bar shows how far along we are.
    # ============================================================
    $count = $selected.Count
    $done  = 0

    foreach ($item in $selected) {
        $name = $item.Name
        $bat  = $item.Bat

        Write-Progress -Activity "Dijon PC Cleanup Tool" `
                       -Status ("Task {0} of {1}: {2}" -f ($done + 1), $count, $name) `
                       -PercentComplete (($done / $count) * 100)

        $target = Get-ChildItem $workDir -Recurse -Filter $bat | Select-Object -First 1
        if (-not $target) {
            Write-Host ""
            Write-Host "  WARNING: $bat was not found inside the package. Skipping." -ForegroundColor Yellow
            $done++
            continue
        }

        Write-Host ""
        Write-Host ("  ===== Task {0} of {1}: {2} =====" -f ($done + 1), $count, $name) -ForegroundColor Green
        Write-Host ""

        try {
            # Runs in this same window; no new admin prompt because we
            # are already elevated.
            & $target.FullName
        }
        catch {
            Write-Host ("  Problem during '{0}': {1}" -f $name, $_.Exception.Message) -ForegroundColor Yellow
        }

        $done++
    }

    Write-Progress -Activity "Dijon PC Cleanup Tool" -Status "All tasks complete" -PercentComplete 100 -Completed

    # Tidy up the temp files
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    $banner = @'

   ___ _  _ ___ _____ _   _    _
  |_ _| \| / __|_   _/_\ | |  | |
   | || .` \__ \ | |/ _ \| |__| |__
  |___|_|\_|___/ |_/_/ \_\____|____|
    ___ ___  __  __ ___ _    ___ _____ ___
   / __/ _ \|  \/  | _ \ |  | __|_   _| __|
  | (_| (_) | |\/| |  _/ |__| _|  | | | _|
   \___\___/|_|  |_|_| |____|___| |_| |___|

'@

    Write-Host $banner -ForegroundColor Green
    Write-Host "  All selected tasks are complete." -ForegroundColor Green
    Write-Host ""
    Read-Host "  Press Enter to close this window"
}
catch {
    # On failure we stay open, otherwise the error vanishes before
    # you can read it.
    Write-Host ""
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Press Enter to close"
}
