@echo off
setlocal

REM ============================================================
REM  Install Apps - Discord, Steam, Logitech G Hub, FACEIT AC,
REM  and the Riot Client (via the Valorant installer - NA region).
REM  Also sets the desktop wallpaper from wallpaper.png.
REM  Double-click, approve the UAC prompt, and it installs all
REM  three apps using winget (Windows' built-in installer).
REM  No menu, no prompts.
REM ============================================================

REM --- If not running as admin, relaunch with elevation ---
REM  (reliable elevation check - looks for the High Mandatory Level
REM   token, which only exists when running elevated)
whoami /groups | find "S-1-16-12288" >nul 2>&1
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

title Install Apps
echo.
echo Running as: %USERNAME%
echo.

set "FAILED=0"

REM ============================================================
REM  Set the desktop wallpaper
REM  The image ships next to this script (wallpaper.png). We copy
REM  it to a permanent spot first, because the folder this script
REM  runs from gets deleted afterwards - pointing the wallpaper at
REM  a temp file would leave a black desktop on next login.
REM ============================================================
echo Setting desktop wallpaper...
set "WP_SRC=%~dp0wallpaper.png"
set "WP_DST=%USERPROFILE%\Pictures\dijon-wallpaper.png"
if not exist "%WP_SRC%" (
    echo   NOTE: wallpaper.png not found - skipping wallpaper.
) else (
    copy /Y "%WP_SRC%" "%WP_DST%" >nul
    if errorlevel 1 (
        echo   WARNING: could not copy the wallpaper image.
        set "FAILED=1"
    ) else (
        REM  "Fill" fit mode
        reg add "HKCU\Control Panel\Desktop" /v WallpaperStyle /t REG_SZ /d 10 /f >nul
        reg add "HKCU\Control Panel\Desktop" /v TileWallpaper  /t REG_SZ /d 0  /f >nul
        REM  Apply it live - no logoff needed
        powershell -NoProfile -Command "Add-Type -MemberDefinition '[DllImport(\"user32.dll\", SetLastError=true)] public static extern bool SystemParametersInfo(int a, int b, string c, int d);' -Name Wp -Namespace Win32; [void][Win32.Wp]::SystemParametersInfo(20,0,'%WP_DST%',3)"
        echo   Wallpaper applied.
    )
)
echo.

REM --- Make sure winget is available before we try to use it ---
where winget >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: winget was not found on this PC.
    echo.
    echo winget ships with modern Windows 11. If it is missing,
    echo install "App Installer" from the Microsoft Store, then
    echo run this again.
    echo.
    exit /b 1
)

echo ============================================================
echo   Installing Discord...
echo ============================================================
winget install --id Discord.Discord -e --source winget --accept-package-agreements --accept-source-agreements --silent
if %errorlevel% neq 0 set "FAILED=1"
echo.

echo ============================================================
echo   Installing Steam...
echo ============================================================
winget install --id Valve.Steam -e --source winget --accept-package-agreements --accept-source-agreements --silent
if %errorlevel% neq 0 set "FAILED=1"
echo.

echo ============================================================
echo   Installing Logitech G HUB...
echo ============================================================
winget install --id Logitech.GHUB -e --source winget --accept-package-agreements --accept-source-agreements --silent
if %errorlevel% neq 0 set "FAILED=1"
echo.

echo ============================================================
echo   Installing FACEIT Anti-Cheat...
echo ============================================================
winget install --id FACEITLTD.FACEITAC -e --source winget --accept-package-agreements --accept-source-agreements --silent
if %errorlevel% neq 0 set "FAILED=1"
echo.

echo ============================================================
echo   Installing Riot Client (via Valorant - NA)...
echo   Note: this installs the Riot Client and registers Valorant.
echo   The full game is NOT downloaded unless you launch it.
echo ============================================================
winget install --id RiotGames.Valorant.NA -e --source winget --accept-package-agreements --accept-source-agreements --silent
if %errorlevel% neq 0 set "FAILED=1"
echo.

echo ============================================================
if "%FAILED%"=="1" (
    echo  WARNING: One or more apps may not have installed.
    echo  A common cause is that the app was already installed -
    echo  in that case you can safely ignore this.
) else (
    echo  All apps installed successfully.
)
echo ============================================================
echo.

endlocal
