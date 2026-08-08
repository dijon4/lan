# ============================================================
#  BOOTSTRAP
#  Downloads the setup package from GitHub, unpacks it to a
#  temp folder, and runs RUN-ALL.bat.
#
#  EDIT THE TWO LINES BELOW with your GitHub username and repo.
# ============================================================

$GitHubUser = "dijon4"
$RepoName   = "lan"

# ------------------------------------------------------------

$ErrorActionPreference = "Stop"
$zipUrl  = "https://github.com/$GitHubUser/$RepoName/archive/refs/heads/main.zip"
$workDir = Join-Path $env:TEMP "tournament-setup"
$zipPath = Join-Path $env:TEMP "tournament-pkg.zip"

try {
    Write-Host ""
    Write-Host "Downloading setup package..." -ForegroundColor Cyan

    # Clear any previous run
    if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
    New-Item -ItemType Directory -Path $workDir | Out-Null

    # Faster download on older PowerShell versions
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "Extracting..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $workDir -Force

    # Strip the "downloaded from the internet" flag from every file,
    # otherwise Windows may refuse to run the .exe
    Get-ChildItem $workDir -Recurse | Unblock-File -ErrorAction SilentlyContinue

    # GitHub wraps everything in a REPO-main folder, so search for the bat
    $target = Get-ChildItem $workDir -Recurse -Filter "RUN-ALL.bat" |
              Select-Object -First 1

    if (-not $target) {
        throw "RUN-ALL.bat was not found inside the package."
    }

    Write-Host "Launching setup..." -ForegroundColor Green
    Write-Host ""

    # Runs from its extracted folder, so it finds ProfileInspector etc.
    Start-Process -FilePath $target.FullName -WorkingDirectory $target.DirectoryName
}
catch {
    Write-Host ""
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to close"
}
