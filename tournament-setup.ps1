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

# Set the display to the highest refresh rate it supports at the CURRENT
# resolution. Uses the built-in Windows display API - no extra tools.
# Keeps the resolution exactly as-is; only the Hz goes up.
function Set-MaxRefreshRate {
    $sig = @'
using System;
using System.Runtime.InteropServices;
public class DijonDisplay {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName;
        public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
        public int dmFields; public int dmPositionX; public int dmPositionY;
        public int dmDisplayOrientation; public int dmDisplayFixedOutput;
        public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
        public int dmDisplayFlags; public int dmDisplayFrequency;
        public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
        public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
    }
    [DllImport("user32.dll")] public static extern int EnumDisplaySettings(string devName, int modeNum, ref DEVMODE devMode);
    [DllImport("user32.dll")] public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
}
'@
    Add-Type -TypeDefinition $sig -ErrorAction SilentlyContinue

    $ENUM_CURRENT_SETTINGS = -1
    $CDS_UPDATEREGISTRY    = 0x00000001
    $DM_PELSWIDTH          = 0x00080000
    $DM_PELSHEIGHT         = 0x00100000
    $DM_DISPLAYFREQUENCY   = 0x00400000

    # Read the current mode (resolution + current Hz).
    $cur = New-Object DijonDisplay+DEVMODE
    $cur.dmSize = [short][System.Runtime.InteropServices.Marshal]::SizeOf([type]([DijonDisplay+DEVMODE]))
    if ([DijonDisplay]::EnumDisplaySettings($null, $ENUM_CURRENT_SETTINGS, [ref]$cur) -eq 0) {
        Log "Refresh rate: could not read current display mode."
        return $false
    }
    $w = $cur.dmPelsWidth
    $h = $cur.dmPelsHeight
    $currentHz = $cur.dmDisplayFrequency
    $bestHz = $currentHz

    # Walk every supported mode; remember the highest Hz at THIS resolution.
    $idx = 0
    while ($true) {
        $m = New-Object DijonDisplay+DEVMODE
        $m.dmSize = [short][System.Runtime.InteropServices.Marshal]::SizeOf([type]([DijonDisplay+DEVMODE]))
        if ([DijonDisplay]::EnumDisplaySettings($null, $idx, [ref]$m) -eq 0) { break }
        if ($m.dmPelsWidth -eq $w -and $m.dmPelsHeight -eq $h -and $m.dmDisplayFrequency -gt $bestHz) {
            $bestHz = $m.dmDisplayFrequency
        }
        $idx++
    }

    if ($bestHz -le $currentHz) {
        Log "Refresh rate: already at the highest ($currentHz Hz) for ${w}x${h}."
        return $true
    }

    $cur.dmDisplayFrequency = $bestHz
    $cur.dmFields = $DM_PELSWIDTH -bor $DM_PELSHEIGHT -bor $DM_DISPLAYFREQUENCY
    $res = [DijonDisplay]::ChangeDisplaySettings([ref]$cur, $CDS_UPDATEREGISTRY)
    Log "Refresh rate: ${w}x${h}  ${currentHz}Hz -> ${bestHz}Hz (result code $res, 0 = success)."
    return ($res -eq 0)
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
    @{ Label = 'Setting max refresh rate';     Action = { Set-MaxRefreshRate } }
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
