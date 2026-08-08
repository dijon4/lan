# ============================================================
#  DIJON PC CLEANUP TOOL - Bootstrap
#  Shows a menu, then downloads and runs the chosen setup.
#
#  EDIT THE TWO LINES BELOW if your repo details change.
# ============================================================

$GitHubUser = "dijon4"
$RepoName   = "lan"

# ------------------------------------------------------------

$ErrorActionPreference = "Stop"

function Show-Menu {
    Write-Host ""
    Write-Host "  +----------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |     LAUNCHED DIJON PC CLEANUP TOOL     |" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   1. Setup NVIDIA + performance settings"
    Write-Host "   2. Windows 11 Cleanup (Default)"
    Write-Host "   3. Windows 11 Cleanup (Custom)"
    Write-Host "   4. Setup both"
    Write-Host "   Q. Quit"
    Write-Host ""
}

# --- Ask until we get something valid ---
$batName = $null
while (-not $batName) {
    Show-Menu
    $choice = Read-Host "  Select an option"

    switch ($choice.Trim().ToUpper()) {
        "1" { $batName = "tournament-setup.bat" }
        "2" { $batName = "run-win11debloat.bat" }
        "3" { $batName = "run-win11debloat-custom.bat" }
        "4" { $batName = "RUN-ALL.bat" }
        "Q" { Write-Host "  Cancelled." -ForegroundColor Yellow; return }
        default {
            Write-Host ""
            Write-Host "  '$choice' isn't an option. Try 1-4 or Q." -ForegroundColor Yellow
        }
    }
}

# --- Download and run ---
$zipUrl  = "https://github.com/$GitHubUser/$RepoName/archive/refs/heads/main.zip"
$workDir = Join-Path $env:TEMP "dijon-cleanup"
$zipPath = Join-Path $env:TEMP "dijon-pkg.zip"

try {
    Write-Host ""
    Write-Host "  Downloading package..." -ForegroundColor Cyan

    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
    New-Item -ItemType Directory -Path $workDir | Out-Null

    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "  Extracting..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force

    # Clear the "downloaded from internet" flag so the .exe will run
    Get-ChildItem $workDir -Recurse | Unblock-File -ErrorAction SilentlyContinue

    $target = Get-ChildItem $workDir -Recurse -Filter $batName | Select-Object -First 1

    if (-not $target) {
        throw "$batName was not found inside the package."
    }

    Write-Host "  Launching $batName ..." -ForegroundColor Green
    Write-Host ""

    Start-Process -FilePath $target.FullName -WorkingDirectory $target.DirectoryName -Wait

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

    Clear-Host
    Write-Host $banner -ForegroundColor Green
    Start-Sleep -Seconds 2

    [Environment]::Exit(0)
}
catch {
    # On failure we stay open, otherwise the error vanishes before
    # you can read it.
    Write-Host ""
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Press Enter to close"
}
