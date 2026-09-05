# ============================================================
#  DIJON WINDOWS SETUP TOOL - Bootstrap
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

# Wipe the PowerShell copyright header immediately, before anything
# else prints, so the very first thing on screen is this tool.
Clear-Host

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

# We are now running in the elevated window. Clear the PowerShell
# copyright header so only our tool is on screen, and set a clean title.
Clear-Host
$Host.UI.RawUI.WindowTitle = "DIJON Windows Setup Tool"

# Each menu number maps to the .bat file it runs. Order here = order shown.
$OptionMap = [ordered]@{
    "1" = @{ Name = "Setup NVIDIA + performance settings";           Bat = "tournament-setup.bat" }
    "2" = @{ Name = "Windows 11 Cleanup (Default)";                  Bat = "run-win11debloat.bat" }
    "3" = @{ Name = "Windows 11 Cleanup (Custom)";                   Bat = "run-win11debloat-custom.bat" }
    "4" = @{ Name = "Install Apps (Discord, Steam, GHUB, Riot, FACEIT AC, Brave) + NVIDIA driver + startup/default tidy"; Bat = "install-apps.bat" }
}

function Show-Menu {
    Write-Host ""
    Write-Host "  +----------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |        DIJON WINDOWS SETUP TOOL        |" -ForegroundColor Cyan
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
        Write-Host "  Closing." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 400
        [Environment]::Exit(0)
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

# --- Banners shown at the end (success vs failure) ---
$SuccessBanner = @'

   ___ _  _ ___ _____ _   _    _
  |_ _| \| / __|_   _/_\ | |  | |
   | || .` \__ \ | |/ _ \| |__| |__
  |___|_|\_|___/ |_/_/ \_\____|____|
    ___ ___  __  __ ___ _    ___ _____ ___
   / __/ _ \|  \/  | _ \ |  | __|_   _| __|
  | (_| (_) | |\/| |  _/ |__| _|  | | | _|
   \___\___/|_|  |_|_| |____|___| |_| |___|

'@

$FailedBanner = @'

   _____ _    ___ _
  |  ___/ \  |_ _| |
  | |_ / _ \  | || |
  |  _/ ___ \ | || |___
  |_|/_/   \_\___|_____|

'@

# Log file - each task appends its output here; "See logs" shows it.
$logPath = Join-Path $env:TEMP "dijon-setup.log"
$env:DIJON_LOG = $logPath
"DIJON Windows Setup Tool - log started $(Get-Date)" | Set-Content -Path $logPath -ErrorAction SilentlyContinue

# Runs a single task (a .bat) and returns $true on success, $false on
# failure. Used for both the first pass and any retries.
function Invoke-DijonTask($item, $index, $count, $work) {
    $target = Get-ChildItem $work -Recurse -Filter $item.Bat | Select-Object -First 1
    if (-not $target) {
        Write-Host ""
        Write-Host "  WARNING: $($item.Bat) was not found inside the package." -ForegroundColor Yellow
        return $false
    }
    Write-Host ""
    Write-Host ("  ===== Task {0} of {1}: {2} =====" -f $index, $count, $item.Name) -ForegroundColor Green
    Write-Host ""
    try {
        $global:LASTEXITCODE = 0
        & $target.FullName
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        Write-Host ("  Problem during '{0}': {1}" -f $item.Name, $_.Exception.Message) -ForegroundColor Yellow
        return $false
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
    #  We are already admin, so these run inline with no prompts.
    #  Each task shows its OWN output/progress (options 1 and 4 draw
    #  a single clean bar), so the launcher does not draw a bar here.
    # ============================================================
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue   # tidy the downloaded zip

    $count  = $selected.Count
    $failed = @()          # tasks that did not succeed
    $idx    = 0
    foreach ($item in $selected) {
        $idx++
        if (-not (Invoke-DijonTask $item $idx $count $workDir)) { $failed += $item }
    }

    # ============================================================
    #  End screen.
    #   - Nothing failed: hold 5s, show the finished banner, close.
    #   - Something failed: show FAIL + a menu (retry / logs / exit)
    #     and loop until it all passes or the user exits.
    # ============================================================
    while ($true) {

        if ($failed.Count -eq 0) {
            Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host ""
            Write-Host "   All selected tasks are complete." -ForegroundColor Green
            for ($s = 5; $s -ge 1; $s--) {
                Write-Host ("`r   Opening summary in {0}... " -f $s) -NoNewline -ForegroundColor DarkGray
                Start-Sleep -Seconds 1
            }
            Clear-Host
            Write-Host $SuccessBanner -ForegroundColor Green
            Write-Host "   All selected tasks are complete." -ForegroundColor Green
            Start-Sleep -Seconds 3
            [Environment]::Exit(0)
        }

        Write-Host ""
        Write-Host $FailedBanner -ForegroundColor Red
        Write-Host ("   Failed: {0}" -f (($failed | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Red
        Write-Host ""
        Write-Host "   1. Retry the failed task(s)"
        Write-Host "   2. See logs"
        Write-Host "   3. Exit"
        Write-Host ""
        $pick = (Read-Host "   Choose 1, 2 or 3").Trim()

        if ($pick -eq "1") {
            $retry  = $failed
            $failed = @()
            $rc = $retry.Count
            $ri = 0
            foreach ($item in $retry) {
                $ri++
                if (-not (Invoke-DijonTask $item $ri $rc $workDir)) { $failed += $item }
            }
        }
        elseif ($pick -eq "2") {
            Write-Host ""
            if (Test-Path $env:DIJON_LOG) {
                Write-Host ("   ----- LOG  ({0}) -----" -f $env:DIJON_LOG) -ForegroundColor Cyan
                Get-Content $env:DIJON_LOG | Out-Host
                Write-Host "   ----- END OF LOG -----" -ForegroundColor Cyan
            }
            else {
                Write-Host "   No log file was found." -ForegroundColor Yellow
            }
            Write-Host ""
            Read-Host "   Press Enter to go back" | Out-Null
        }
        elseif ($pick -eq "3") {
            Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
            [Environment]::Exit(1)
        }
        else {
            Write-Host "   Please enter 1, 2 or 3." -ForegroundColor Yellow
        }
    }
}
catch {
    # A hard failure (download, extract, etc.): never auto-close, show red
    # so nothing is lost before it can be read.
    Write-Progress -Activity "Dijon Windows Setup Tool" -Completed
    Write-Host $FailedBanner -ForegroundColor Red
    Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "   Press Enter to close" | Out-Null
    [Environment]::Exit(1)
}
