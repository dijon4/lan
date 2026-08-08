@echo off
setlocal

REM ============================================================
REM  Tournament Setup - Power Settings + Game DVR
REM  Just double-click. Approve the UAC prompt when it appears.
REM  Applies immediately. No restart required.
REM ============================================================

REM --- If not running as admin, relaunch with elevation ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    if errorlevel 1 (
        echo.
        echo Could not elevate. Right-click this file and choose
        echo "Run as administrator" instead.
        echo.
    )
    exit /b
)

title Tournament Setup
echo.
echo Running as: %USERNAME%
echo.
echo Applying power settings...
echo.

set "FAILED=0"

REM --- High Performance power plan ---
powercfg /setactive SCHEME_MIN
if %errorlevel% neq 0 set "FAILED=1"

REM --- Disable idle timeouts (0 = never) ---
powercfg /change monitor-timeout-ac 0
powercfg /change standby-timeout-ac 0
powercfg /change disk-timeout-ac 0
powercfg /change hibernate-timeout-ac 0 >nul 2>&1

REM --- Disable USB selective suspend ---
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
if %errorlevel% neq 0 set "FAILED=1"

REM --- PCIe link state power management: Off ---
powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0

REM --- Pin CPU min and max processor state to 100%% ---
powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100

REM --- Re-apply so changes take effect immediately ---
powercfg /setactive SCHEME_CURRENT
if %errorlevel% neq 0 set "FAILED=1"

echo Power settings done.
echo.
echo Disabling Game DVR / background recording...
echo.

REM ============================================================
REM  GAME DVR
REM  One machine-wide policy key, plus per-user keys.
REM  Takes effect the next time the game is launched.
REM ============================================================

REM --- Machine-wide policy: blocks Game DVR for all users ---
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul
if %errorlevel% neq 0 set "FAILED=1"

REM --- Per-user: disables background capture and the DVR toggle ---
REM  NOTE: these write to whichever account this script is running as.
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul

REM --- Suppress the Xbox Game Bar startup popup ---
reg add "HKCU\Software\Microsoft\GameBar" /v ShowStartupPanel /t REG_DWORD /d 0 /f >nul

echo Game DVR disabled.

echo.
echo Disabling mouse acceleration...
echo.

REM ============================================================
REM  MOUSE ACCELERATION ("Enhance pointer precision")
REM  All three values must be 0 to fully disable it.
REM  NOTE: per-user setting - applies to the account running this.
REM ============================================================

reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f >nul

REM --- OPTIONAL: set pointer speed to 6/11 (true 1-to-1, no scaling).
REM     Remove the "REM " below if you want this enforced too.
REM reg add "HKCU\Control Panel\Mouse" /v MouseSensitivity /t REG_SZ /d 10 /f >nul

REM --- Tell Windows to reload mouse settings NOW, without a logoff ---
powershell -NoProfile -Command "Add-Type -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool SystemParametersInfo(uint a, uint b, int[] c, uint d);' -Name W -Namespace N; $p=@(0,0,0); [void][N.W]::SystemParametersInfo(4,0,$p,3)" >nul 2>&1
if errorlevel 1 (
    echo WARNING: Could not apply mouse setting live.
    echo A logoff/logon would be needed for it to take effect.
    set "FAILED=1"
) else (
    echo Mouse acceleration disabled.
)

echo.
echo Applying NVIDIA profile settings...
echo.

REM ============================================================
REM  NVIDIA DRIVER PROFILE
REM  %~dp0 = the folder this script is in, so this works on any
REM  drive letter the USB stick happens to get.
REM  Expected layout on the stick:
REM     tournament-setup.bat
REM     ProfileInspector\nvidiaProfileInspector.exe
REM     tournament.nip
REM ============================================================

set "NVPI=%~dp0ProfileInspector\nvidiaProfileInspector.exe"
set "NIP=%~dp0tournament.nip"

if not exist "%NVPI%" (
    echo WARNING: Profile Inspector not found at:
    echo   %NVPI%
    echo NVIDIA settings SKIPPED.
    set "FAILED=1"
) else (
    if not exist "%NIP%" (
        echo WARNING: Profile file not found at:
        echo   %NIP%
        echo NVIDIA settings SKIPPED.
        set "FAILED=1"
    ) else (
        "%NVPI%" -silentImport "%NIP%"
        if errorlevel 1 (
            echo WARNING: Profile import reported an error.
            set "FAILED=1"
        ) else (
            echo NVIDIA profile imported successfully.
        )
    )
)

echo.
echo ============================================================
if "%FAILED%"=="1" (
    echo  WARNING: One or more settings may not have applied.
) else (
    echo  All settings applied successfully.
)
echo.
powercfg /getactivescheme
echo.
echo  Launch CS2 AFTER running this, not before.
echo  If NVIDIA Control Panel was open, close and reopen it.
echo ============================================================
echo.

REM --- Log any problem so nothing is lost when the window closes ---
if "%FAILED%"=="1" (
    echo  SOMETHING NEEDS ATTENTION - see setup-log.txt on the Desktop.
    echo Tournament setup reported a problem on %COMPUTERNAME% at %DATE% %TIME% > "%USERPROFILE%\Desktop\setup-log.txt"
    powercfg /getactivescheme >> "%USERPROFILE%\Desktop\setup-log.txt"
)

endlocal
