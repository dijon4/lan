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

# Summary file - the app installer writes a machine-readable list of
# what it installed / already had / failed; the final screen reads it.
$summaryPath = Join-Path $env:TEMP "dijon-summary.txt"
$env:DIJON_SUMMARY = $summaryPath
Set-Content -Path $summaryPath -Value $null -ErrorAction SilentlyContinue

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

# Turns a .bat file name into the friendly heading shown on the summary.
function Get-TaskLabel($bat) {
    switch ($bat) {
        "tournament-setup.bat"        { "Graphics settings" }
        "run-win11debloat.bat"        { "Windows 11 debloat" }
        "run-win11debloat-custom.bat" { "Windows 11 debloat" }
        "install-apps.bat"            { "App install" }
        default                       { $bat }
    }
}

# Draws the final report card: a Complete/Failed line for each task that
# was run, plus - if the app installer ran - a breakdown of what was
# downloaded, what the PC already had, and what failed.
function Show-FinalSummary($status, $summaryPath) {
    Write-Host ""
    Write-Host "   ================= SUMMARY =================" -ForegroundColor Cyan
    foreach ($name in $status.Keys) {
        if ($status[$name]) {
            Write-Host ("   {0,-22} Complete" -f $name) -ForegroundColor Green
        } else {
            Write-Host ("   {0,-22} Failed"   -f $name) -ForegroundColor Red
        }
    }

    # App-level breakdown (only present if the App install step ran).
    if ($summaryPath -and (Test-Path $summaryPath)) {
        $installed = @(); $already = @(); $failedApps = @()
        foreach ($line in (Get-Content $summaryPath -ErrorAction SilentlyContinue)) {
            if ($line -notmatch '\|') { continue }
            $parts = $line.Split('|', 2)
            switch ($parts[0]) {
                "Installed"         { $installed  += $parts[1] }
                "Already installed" { $already    += $parts[1] }
                "Failed"            { $failedApps += $parts[1] }
            }
        }
        if ($installed.Count -or $already.Count -or $failedApps.Count) {
            Write-Host ""
            Write-Host "   Apps:" -ForegroundColor Cyan
            if ($installed.Count)  { Write-Host ("     Downloaded : {0}" -f ($installed  -join ', ')) -ForegroundColor Green }
            if ($already.Count)    { Write-Host ("     Already had: {0}" -f ($already    -join ', ')) -ForegroundColor DarkGray }
            if ($failedApps.Count) { Write-Host ("     Failed     : {0}" -f ($failedApps -join ', ')) -ForegroundColor Red }
        }
    }
    Write-Host "   ==========================================" -ForegroundColor Cyan
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
    $status = [ordered]@{} # friendly task name -> $true (complete) / $false (failed)
    $idx    = 0
    foreach ($item in $selected) {
        $idx++
        $taskOk = Invoke-DijonTask $item $idx $count $workDir
        $status[(Get-TaskLabel $item.Bat)] = $taskOk
        if (-not $taskOk) { $failed += $item }
    }

    # ============================================================
    #  End screen.
    #   - Nothing failed: hold 5s, show the finished banner, close.
    #   - Something failed: show FAIL + a menu (retry / logs / exit)
    #     and loop until it all passes or the user exits.
    # ============================================================
    while ($true) {

        if ($failed.Count -eq 0) {
            # Nothing failed (apps that were skipped because they're
            # already installed do NOT count as failures) -> show the
            # summary and close on its own after a short readable pause.
            Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
            Clear-Host
            Write-Host $SuccessBanner -ForegroundColor Green
            Write-Host "   All selected tasks are complete." -ForegroundColor Green
            Show-FinalSummary $status $summaryPath
            Write-Host ""
            for ($s = 10; $s -ge 1; $s--) {
                Write-Host ("`r   Closing in {0}...  " -f $s) -NoNewline -ForegroundColor DarkGray
                Start-Sleep -Seconds 1
            }
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
                $taskOk = Invoke-DijonTask $item $ri $rc $workDir
                $status[(Get-TaskLabel $item.Bat)] = $taskOk
                if (-not $taskOk) { $failed += $item }
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
            Show-FinalSummary $status $summaryPath
            Write-Host ""
            Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
            Read-Host "   Press Enter to close" | Out-Null
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
