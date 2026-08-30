@echo off
setlocal

REM ============================================================
REM  DIJON Windows Setup Tool - NVIDIA + Performance (launcher)
REM  This is just a small wrapper. The real work - power settings,
REM  Game DVR, mouse acceleration and the NVIDIA profile import -
REM  is done by tournament-setup.ps1 next to this file, which shows
REM  a single clean progress bar.
REM ============================================================

REM --- If not running as admin, relaunch with elevation ---
REM  (reliable elevation check via the High Mandatory Level token)
whoami /groups | find "S-1-16-12288" >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

REM --- Run the settings script and pass its result back out ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tournament-setup.ps1"
exit /b %errorlevel%
