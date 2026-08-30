@echo off
setlocal

REM ============================================================
REM  Install Apps - Discord, Steam, Logitech G Hub
REM  Double-click, approve the UAC prompt, and it installs all
REM  three apps using winget (Windows' built-in installer).
REM  No menu, no prompts.
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

title Install Apps
echo.
echo Running as: %USERNAME%
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
    pause
    exit /b 1
)

set "FAILED=0"

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
