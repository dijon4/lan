@echo off
setlocal

REM ============================================================
REM  DIJON Windows Setup Tool - Install Apps (launcher)
REM  This is just a small wrapper. The real work - installing
REM  Discord, Steam, Logitech G HUB, FACEIT AC and the Riot
REM  Client, setting the wallpaper, and making desktop shortcuts -
REM  is done by install-apps.ps1 next to this file, which shows a
REM  single clean progress bar.
REM ============================================================

REM --- If not running as admin, relaunch with elevation ---
REM  (reliable elevation check via the High Mandatory Level token)
whoami /groups | find "S-1-16-12288" >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

REM --- Run the installer script and pass its result back out ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-apps.ps1"
exit /b %errorlevel%
