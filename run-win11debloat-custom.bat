@echo off
REM ============================================================
REM  Win11Debloat launcher - CUSTOM MODE
REM  Opens the script's own menu so you choose what to apply.
REM  Note: this one DOES wait for your input, by design.
REM ============================================================

REM  (reliable elevation check via the High Mandatory Level token)
whoami /groups | find "S-1-16-12288" >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

title Win11Debloat - Custom

echo.
echo Loading Win11Debloat menu...
echo.

REM --- NO parameters at all. Any parameter makes the script skip
REM     the menu and run unattended, which is what broke this before.
REM     The wizard offers a restore point itself.
REM     Add -CLI below if you prefer the old text menu to the GUI.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/')))"

echo.
echo Done. Sign out and back in for all changes to take effect.
