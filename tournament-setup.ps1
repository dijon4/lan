# ============================================================
#  DIJON Windows Setup Tool - NVIDIA + Performance Settings
#  Runs the whole performance step under ONE clean progress bar.
#
#  - The current step is shown above the bar.
#  - Any failures are printed below the bar in red as they happen.
#  - Exits with code 1 if anything failed, otherwise 0, so the
#    launcher (bootstrap.ps1) can pick the right end screen.
#
#  Assumes it is already running as administrator (bootstrap.ps1,
#  or tournament-setup.bat, guarantees that).
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference    = "Continue"

$failures = @()

# Where to append detail so the launcher's "See logs" can show it.
$LogFile = if ($env:DIJON_LOG) { $env:DIJON_LOG } else { Join-Path $env:TEMP 'dijon-setup.log' }
function Log($msg) { Add-Content -Path $LogFile -Value $msg -ErrorAction SilentlyContinue }
Log ""
Log "==================================================="
Log "NVIDIA + Performance Settings  -  $(Get-Date)"
Log "==================================================="

# ------------------------------------------------------------
#  Steps
# ------------------------------------------------------------

# High Performance power plan + idle timeouts off + USB/PCIe/CPU tweaks.
function Set-PowerSettings {
    $ok = $true

    powercfg /setactive SCHEME_MIN | Out-Null
    if ($LASTEXITCODE -ne 0) { $ok = $false }

    powercfg /change monitor-timeout-ac 0   | Out-Null
    powercfg /change standby-timeout-ac 0   | Out-Null
    powercfg /change disk-timeout-ac 0      | Out-Null
    powercfg /change hibernate-timeout-ac 0 2>$null | Out-Null

    # USB selective suspend: off
    powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
    if ($LASTEXITCODE -ne 0) { $ok = $false }
    # PCIe link state power management: off
    powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 | Out-Null
    # CPU min and max processor state: 100%
    powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 | Out-Null

    powercfg /setactive SCHEME_CURRENT | Out-Null
    if ($LASTEXITCODE -ne 0) { $ok = $false }

    return $ok
}

# Disable Game DVR / background recording (machine-wide + per-user).
function Disable-GameDVR {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f | Out-Null
    $ok = ($LASTEXITCODE -eq 0)
    reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKCU\Software\Microsoft\GameBar" /v ShowStartupPanel /t REG_DWORD /d 0 /f | Out-Null
    return $ok
}

# Disable mouse acceleration ("Enhance pointer precision") and apply live.
function Disable-MouseAccel {
    reg add "HKCU\Control Panel\Mouse" /v MouseSpeed      /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f | Out-Null
    reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f | Out-Null

    Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint a, uint b, int[] c, uint d);' -Name Mouse -Namespace DijonN -ErrorAction SilentlyContinue
    $p = @(0, 0, 0)
    [void][DijonN.Mouse]::SystemParametersInfo(4, 0, $p, 3)
    return $true   # registry values are what matter; live refresh is best-effort
}

# Import the NVIDIA profile via Profile Inspector.
function Import-NvidiaProfile {
    $nvpi = Join-Path $PSScriptRoot 'ProfileInspector\nvidiaProfileInspector.exe'
    $nip  = Join-Path $PSScriptRoot 'tournament.nip'
    if (-not (Test-Path $nvpi)) { return $false }
    if (-not (Test-Path $nip))  { return $false }
    & $nvpi -silentImport $nip | Out-Null
    return ($LASTEXITCODE -eq 0)
}

$steps = @(
    @{ Label = 'Applying power settings';      Action = { Set-PowerSettings } }
    @{ Label = 'Disabling Game DVR';           Action = { Disable-GameDVR } }
    @{ Label = 'Disabling mouse acceleration'; Action = { Disable-MouseAccel } }
    @{ Label = 'Applying NVIDIA profile';      Action = { Import-NvidiaProfile } }
)

# ------------------------------------------------------------
#  Run the steps under a single progress bar
# ------------------------------------------------------------
$total = $steps.Count
$i     = 0

foreach ($step in $steps) {
    $i++
    $pct = [int]((($i - 1) / $total) * 100)
    Write-Progress -Activity "Applying NVIDIA + performance settings" `
                   -Status ("[{0}/{1}]  {2}" -f $i, $total, $step.Label) `
                   -PercentComplete $pct

    $ok = $false
    try { $ok = & $step.Action } catch { $ok = $false; Log ("EXCEPTION in {0}: {1}" -f $step.Label, $_.Exception.Message) }

    if (-not $ok) {
        $short = $step.Label -replace '^(Applying|Disabling|Setting|Creating)\s+', ''
        $failures += $short
        Write-Host ("   FAILED: {0}" -f $short) -ForegroundColor Red
        Log ("STEP FAILED: {0}" -f $step.Label)
    }
    else {
        Log ("OK: {0}" -f $step.Label)
    }
}

Write-Progress -Activity "Applying NVIDIA + performance settings" -Completed

if ($failures.Count -gt 0) {
    Log ("RESULT: FAILED - " + ($failures -join ', '))
    exit 1
} else {
    Log "RESULT: all steps OK"
    exit 0
}
