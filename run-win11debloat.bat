@echo off
REM ============================================================
REM  Win11Debloat launcher
REM  Double-click, approve the UAC prompt, and it applies the
REM  default set automatically. No menu, no prompts.
REM
REM  Swap -RunDefaults for -RunDefaultsLite below if you want a
REM  lighter set of changes.
REM ============================================================

REM --- Elevate if we aren't already admin ---
REM  (reliable elevation check via the High Mandatory Level token)
whoami /groups | find "S-1-16-12288" >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

title Win11Debloat

echo Running Win11Debloat with default settings...
echo.

REM --- Download and run, applying defaults with no prompts ---
REM  -CreateRestorePoint gives you a way back if you don't like it.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/'))) -RunDefaults -Silent -CreateRestorePoint"

echo.
echo Done. Sign out and back in for all changes to take effect.

