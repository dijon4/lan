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

# Where to append detailed output so the launcher's "See logs" can show it.
$LogFile = if ($env:DIJON_LOG) { $env:DIJON_LOG } else { Join-Path $env:TEMP 'dijon-setup.log' }
function Log($msg) { Add-Content -Path $LogFile -Value $msg -ErrorAction SilentlyContinue }
Log ""
Log "==================================================="
Log "Install Apps  -  $(Get-Date)"
Log "==================================================="

# ------------------------------------------------------------
#  Detect already-installed apps (so we can skip them)
#  We read every program's name from the Windows uninstall list
#  once, up front. Steps can then check that list (and/or a known
#  file path) and be skipped if the app is already present.
# ------------------------------------------------------------
$script:InstalledNames = @()
foreach ($root in @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
        $dn = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName
        if ($dn) { $script:InstalledNames += $dn.ToLower() }
    }
}

# Returns $true if the app looks already installed: either one of the
# given files exists, or any of the name patterns matches an installed
# program. Used to skip installs on re-runs.
function Test-Installed {
    param([string[]]$Names = @(), [string[]]$Paths = @())
    foreach ($p in $Paths) { if ($p -and (Test-Path $p)) { return $true } }
    foreach ($n in $Names) {
        $nl = $n.ToLower()
        if ($script:InstalledNames | Where-Object { $_ -like "*$nl*" }) { return $true }
    }
    return $false
}

# ------------------------------------------------------------
#  Helpers
# ------------------------------------------------------------

# Install one winget package silently. Returns $true on success,
# and also treats "already installed / nothing to do" as success
# so re-running the tool doesn't show false failures. The full winget
# output is written to the log either way.
function Install-App($id) {
    Log ""
    Log "--- winget install $id ---"
    $out  = winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --silent --disable-interactivity 2>&1
    $code = $LASTEXITCODE
    $text = ($out | Out-String)
    Log $text
    Log "exit code: $code"

    if ($code -eq 0) { return $true }

    if ($text -match 'already installed' -or
        $text -match 'No newer'          -or
        $text -match 'No applicable'     -or
        $text -match 'no available upgrade' -or
        $code -eq -1978335189) {
        Log "(treated as success: already installed / nothing to do)"
        return $true
    }
    return $false
}

# Discord ships a self-elevating installer, so installing it through
# winget can pop an extra "allow?" prompt even when we are already
# admin. Running Discord's own installer directly from this elevated
# session avoids winget's context switch and, in most cases, that
# second prompt. Best-effort: success = Discord's files are present.
function Install-Discord {
    Log ""
    Log "--- Discord (direct installer) ---"
    $url = 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64'
    $exe = Join-Path $env:TEMP 'DiscordSetup.exe'
    try {
        Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
    } catch {
        Log "Discord download failed: $($_.Exception.Message)"
        return $false
    }
    try {
        # Squirrel installer: --silent installs without showing the setup UI.
        Start-Process -FilePath $exe -ArgumentList '--silent' -Wait -ErrorAction SilentlyContinue
    } catch {
        Log "Discord installer error: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 3
    $installed = Test-Path (Join-Path $env:LOCALAPPDATA 'Discord\Update.exe')
    Log "Discord installed: $installed"
    return $installed
}

# The NVIDIA App is NOT in the winget catalogue, so we fetch NVIDIA's
# own installer straight from their site and run it silently. The
# download link changes with each version, so we read the current one
# off NVIDIA's page rather than hard-coding it (which would rot).
function Install-NvidiaApp {
    Log ""
    Log "--- NVIDIA App (official installer) ---"
    try {
        $page = Invoke-WebRequest -Uri 'https://www.nvidia.com/en-us/software/nvidia-app/' -UseBasicParsing
        $m = [regex]::Match($page.Content, 'https://us\.download\.nvidia\.com/nvapp/client/[\d\.]+/NVIDIA_app_v[\d\.]+\.exe')
        if (-not $m.Success) {
            Log "Could not find the NVIDIA App download link on NVIDIA's page."
            return $false
        }
        $url = $m.Value
        Log "NVIDIA App URL: $url"
        $exe = Join-Path $env:TEMP 'NVIDIA_App.exe'
        Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
        # NVIDIA's silent switches: silent, no reboot, no EULA/finish/splash screens.
        $p = Start-Process -FilePath $exe -ArgumentList '-s','-noreboot','-noeula','-nofinish','-nosplash' -Wait -PassThru
        Log "NVIDIA App installer exit code: $($p.ExitCode)"
        return ($p.ExitCode -eq 0)
    } catch {
        Log "NVIDIA App install failed: $($_.Exception.Message)"
        return $false
    }
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

# Apply Brave's privacy / debloat settings machine-wide via Brave's
# enterprise policies (the same registry keys SlimBrave writes). These
# live in the registry, so they survive the per-login data wipe below.
function Set-BravePolicies {
    $base = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'
    try {
        New-Item -Path $base -Force | Out-Null

        # name = value (all DWORD). 1 usually means "disabled/off",
        # 0 means "feature off", depending on how each policy is named.
        $policies = [ordered]@{
            # --- Brave bloat: Rewards, Wallet, VPN, AI (Leo), Tor, News ---
            'BraveRewardsDisabled'                    = 1
            'BraveWalletDisabled'                     = 1
            'BraveVPNDisabled'                        = 1
            'BraveAIChatEnabled'                      = 0
            'TorDisabled'                             = 1
            'BraveNewsDisabled'                       = 1
            # --- Telemetry / data collection ---
            'MetricsReportingEnabled'                 = 0
            'UrlKeyedAnonymizedDataCollectionEnabled' = 0
            'SafeBrowsingExtendedReportingEnabled'    = 0
            'FeedbackSurveysEnabled'                  = 0
            # --- Clutter ---
            'ShoppingListEnabled'                     = 0
            'PromotionsEnabled'                       = 0
            'MediaRecommendationsEnabled'             = 0
            'SearchSuggestEnabled'                    = 0
            'TranslateEnabled'                        = 0
            # --- Shared-PC hygiene: stop personal data being stored ---
            'SyncDisabled'                            = 1
            'BrowserSignin'                           = 0
            'PasswordManagerEnabled'                  = 0
            'AutofillAddressEnabled'                  = 0
            'AutofillCreditCardEnabled'               = 0
            # We set the default browser manually, so silence Brave's own nag.
            'DefaultBrowserSettingEnabled'            = 0
        }

        foreach ($name in $policies.Keys) {
            New-ItemProperty -Path $base -Name $name -Value $policies[$name] -PropertyType DWord -Force | Out-Null
        }
        Log "Brave policies written to $base"
        return $true
    } catch {
        Log "Brave policy error: $($_.Exception.Message)"
        return $false
    }
}

# Shared-PC housekeeping that must run at EVERY login, so we install a
# small maintenance script to a permanent folder and register a
# scheduled task that runs it when someone logs on. The script:
#   1. Wipes Brave's saved data  -> every restart = a fresh browser.
#   2. Strips auto-start entries for the game apps (keeps anti-cheat)
#      -> so they don't creep back into startup after being used.
function Set-Maintenance {
    try {
        $dir = 'C:\ProgramData\DijonSetup'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $script = Join-Path $dir 'maintenance.ps1'

        $content = @'
# DIJON per-login maintenance. Runs as the logged-on user at each login.
$ErrorActionPreference = 'SilentlyContinue'

# --- 1) Wipe Brave so each session starts clean ---
Get-Process brave -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
$ud = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data'
if (Test-Path $ud) { Remove-Item "$ud\*" -Recurse -Force -ErrorAction SilentlyContinue }

# --- 2) Keep the game apps out of startup (but NEVER touch anti-cheat) ---
$disable = @('discord','steam','ghub','logitech','riot','brave','epicgames','epic games launcher')
$keep    = @('faceit','vanguard','vgc','vgtray','anticheat','anti-cheat','riotclientservices')

$runKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($rk in $runKeys) {
    if (-not (Test-Path $rk)) { continue }
    foreach ($name in (Get-Item $rk).Property) {
        $data = (Get-ItemProperty -Path $rk -Name $name -ErrorAction SilentlyContinue).$name
        $hay  = ("$name $data").ToLower()
        if ($keep    | Where-Object { $hay -like "*$_*" }) { continue }
        if ($disable | Where-Object { $hay -like "*$_*" }) {
            Remove-ItemProperty -Path $rk -Name $name -Force -ErrorAction SilentlyContinue
        }
    }
}
'@
        Set-Content -Path $script -Value $content -Encoding UTF8 -Force

        # Register (or refresh) the login task. Runs in the interactive
        # user's context with highest privileges so it can reach both the
        # user's Brave data and the machine-wide startup keys.
        $action    = New-ScheduledTaskAction   -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
        $trigger   = New-ScheduledTaskTrigger  -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Highest
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName 'DijonMaintenance' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
        Log "Registered DijonMaintenance login task ($script)"

        # Run it once now so the machine is clean immediately after setup.
        try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script | Out-Null } catch {}
        return $true
    } catch {
        Log "Maintenance setup failed: $($_.Exception.Message)"
        return $false
    }
}

# One-time strip of the game apps from startup right now (the login task
# above keeps it that way afterwards). Anti-cheat is always left alone.
function Disable-StartupApps {
    $disable = @('discord','steam','ghub','logitech','riot','brave','epicgames','epic games launcher')
    $keep    = @('faceit','vanguard','vgc','vgtray','anticheat','anti-cheat','riotclientservices')

    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    foreach ($rk in $runKeys) {
        if (-not (Test-Path $rk)) { continue }
        foreach ($name in (Get-Item $rk).Property) {
            $data = (Get-ItemProperty -Path $rk -Name $name -ErrorAction SilentlyContinue).$name
            $hay  = ("$name $data").ToLower()
            if ($keep    | Where-Object { $hay -like "*$_*" }) { continue }
            if ($disable | Where-Object { $hay -like "*$_*" }) {
                Remove-ItemProperty -Path $rk -Name $name -Force -ErrorAction SilentlyContinue
                Log "Removed startup entry: $name ($rk)"
            }
        }
    }

    $folders = @([Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup'))
    foreach ($f in $folders) {
        Get-ChildItem $f -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
            $n = $_.BaseName.ToLower()
            if ($keep    | Where-Object { $n -like "*$_*" }) { return }
            if ($disable | Where-Object { $n -like "*$_*" }) {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Log "Removed startup shortcut: $($_.Name)"
            }
        }
    }
    return $true
}

# ------------------------------------------------------------
#  Build the list of steps
#  (NeedsWinget marks steps that require winget so we can drop
#   just those if winget is missing.)
# ------------------------------------------------------------
$steps = @(
    @{ Label = 'Setting desktop wallpaper';    NeedsWinget = $false; Action = { Set-Wallpaper } }
    @{ Label = 'Installing Discord';           NeedsWinget = $false; Action = { Install-Discord }
       Check = { Test-Installed -Names @('Discord') -Paths @((Join-Path $env:LOCALAPPDATA 'Discord\Update.exe')) } }
    @{ Label = 'Installing Steam';             NeedsWinget = $true;  Action = { Install-App 'Valve.Steam' }
       Check = { Test-Installed -Names @('Steam') -Paths @((Join-Path ${env:ProgramFiles(x86)} 'Steam\steam.exe')) } }
    @{ Label = 'Installing Logitech G HUB';    NeedsWinget = $true;  Action = { Install-App 'Logitech.GHUB' }
       Check = { Test-Installed -Names @('G HUB','Logitech G HUB') -Paths @((Join-Path $env:ProgramFiles 'LGHUB\lghub.exe')) } }
    @{ Label = 'Installing FACEIT Anti-Cheat'; NeedsWinget = $true;  Action = { Install-App 'FACEITLTD.FACEITAC' }
       Check = { Test-Installed -Names @('FACEIT') } }
    @{ Label = 'Installing Riot Client';       NeedsWinget = $true;  Action = { Install-App 'RiotGames.Valorant.NA' }
       Check = { Test-Installed -Names @('VALORANT','Riot') -Paths @('C:\Riot Games\Riot Client\RiotClientServices.exe') } }
    @{ Label = 'Installing NVIDIA App';        NeedsWinget = $false; Action = { Install-NvidiaApp }
       Check = { Test-Installed -Names @('NVIDIA App') } }
    @{ Label = 'Installing Brave';             NeedsWinget = $true;  Action = { Install-App 'Brave.Brave' }
       Check = { Test-Installed -Names @('Brave') } }
    @{ Label = 'Applying Brave privacy settings'; NeedsWinget = $false; Action = { Set-BravePolicies } }
    @{ Label = 'Setting up Brave auto-clean';  NeedsWinget = $false; Action = { Set-Maintenance } }
    @{ Label = 'Tidying startup apps';         NeedsWinget = $false; Action = { Disable-StartupApps } }
)

# If winget is missing, the winget-based steps can't run. Say so once
# and drop only those; the rest (wallpaper, Discord, NVIDIA App, Brave
# config, startup tidy) still run.
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "   winget was not found - some app installs will be skipped." -ForegroundColor Red
    Write-Host "   Install 'App Installer' from the Microsoft Store to enable them." -ForegroundColor Red
    $failures += 'winget not available (some apps skipped)'
    $steps = $steps | Where-Object { -not $_.NeedsWinget }
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

    # Skip this step if the app is already installed.
    if ($step.Check) {
        $present = $false
        try { $present = & $step.Check } catch { $present = $false }
        if ($present) {
            $shortSkip = $step.Label -replace '^Installing\s+', ''
            Write-Host ("   Already installed - skipped {0}" -f $shortSkip) -ForegroundColor DarkGray
            Log ("SKIP (already installed): {0}" -f $step.Label)
            continue
        }
    }

    $ok = $false
    try { $ok = & $step.Action } catch { $ok = $false; Log ("EXCEPTION in {0}: {1}" -f $step.Label, $_.Exception.Message) }

    if (-not $ok) {
        # Trim "Installing " / "Setting " etc. for a tidy failure label
        $short = $step.Label -replace '^(Installing|Setting|Creating|Applying|Tidying)\s+', ''
        $failures += $short
        Write-Host ("   FAILED: {0}" -f $short) -ForegroundColor Red
        Log ("STEP FAILED: {0}" -f $step.Label)
    }
}

Write-Progress -Activity "Installing important apps" -Completed

# ------------------------------------------------------------
#  One-time manual step: make Brave the default browser.
#  Windows 11 blocks setting this silently, so we open the Default
#  Apps page and ask the person setting up the PC to click once.
#  This is skipped from the pass/fail tally - it's a manual step.
# ------------------------------------------------------------
$bravePaths = @(
    (Join-Path $env:ProgramFiles       'BraveSoftware\Brave-Browser\Application\brave.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'BraveSoftware\Brave-Browser\Application\brave.exe'),
    (Join-Path $env:LOCALAPPDATA       'BraveSoftware\Brave-Browser\Application\brave.exe')
)
if ($bravePaths | Where-Object { Test-Path $_ }) {
    Write-Host ""
    Write-Host "  +------------------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "  |  ONE-TIME STEP: make Brave the default browser             |" -ForegroundColor Yellow
    Write-Host "  |  Windows is opening its 'Default apps' page now.           |" -ForegroundColor Yellow
    Write-Host "  |    1. Type  Brave  in the search box                       |" -ForegroundColor Yellow
    Write-Host "  |    2. Click Brave, then click 'Set default'                |" -ForegroundColor Yellow
    Write-Host "  |  You only need to do this once per PC.                     |" -ForegroundColor Yellow
    Write-Host "  +------------------------------------------------------------+" -ForegroundColor Yellow
    Start-Process 'ms-settings:defaultapps' -ErrorAction SilentlyContinue
    Log "Opened Default Apps page for one-time Brave default selection."
}

if ($failures.Count -gt 0) {
    Log ("RESULT: FAILED - " + ($failures -join ', '))
    exit 1
} else {
    Log "RESULT: all steps OK"
    exit 0
}
