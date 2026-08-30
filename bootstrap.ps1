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
    "4" = @{ Name = "Install Important Apps (Discord, Steam, Riot, GHUB)"; Bat = "install-apps.bat" }
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

   _____ _    ___ _     _____ ___
  |  ___/ \  |_ _| |   | ____|   \
  | |_ / _ \  | || |   |  _| | |) |
  |  _/ ___ \ | || |__ | |___|  _/
  |_|/_/   \_\___|____||_____|_|

'@

# Tracks whether anything went wrong so we know which banner to show.
$anyFailed = $false

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
    #  Each task shows its OWN output/progress (option 4 draws a
    #  single clean bar), so the launcher does not draw a bar of
    #  its own here - it just prints a header before each task.
    # ============================================================
    $count = $selected.Count
    $done  = 0

    foreach ($item in $selected) {
        $name = $item.Name
        $bat  = $item.Bat

        $target = Get-ChildItem $workDir -Recurse -Filter $bat | Select-Object -First 1
        if (-not $target) {
            Write-Host ""
            Write-Host "  WARNING: $bat was not found inside the package. Skipping." -ForegroundColor Yellow
            $anyFailed = $true
            $done++
            continue
        }

        Write-Host ""
        Write-Host ("  ===== Task {0} of {1}: {2} =====" -f ($done + 1), $count, $name) -ForegroundColor Green
        Write-Host ""

        try {
            # Runs in this same window; no new admin prompt because we
            # are already elevated.
            $global:LASTEXITCODE = 0
            & $target.FullName
            # A task that ends with a non-zero exit code (e.g. the app
            # installer reporting a failed install) counts as a failure.
            if ($LASTEXITCODE -ne 0) { $anyFailed = $true }
        }
        catch {
            Write-Host ("  Problem during '{0}': {1}" -f $name, $_.Exception.Message) -ForegroundColor Yellow
            $anyFailed = $true
        }

        $done++
    }

    # Remove the progress bar so it doesn't linger on the final screen
    Write-Progress -Activity "Dijon Windows Setup Tool" -Completed

    # Tidy up the temp files
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    if ($anyFailed) {
        # --- Something went wrong: stay open, show red, keep the log ---
        Write-Host ""
        Write-Host $FailedBanner -ForegroundColor Red
        Write-Host "   One or more tasks reported a problem (see the red items above)." -ForegroundColor Red
        Write-Host ""
        Read-Host "   Press Enter to close" | Out-Null
        [Environment]::Exit(1)
    }
    else {
        # --- All good: hold 5 seconds, then show the finished banner ---
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
