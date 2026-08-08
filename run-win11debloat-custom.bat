@echo off
REM ============================================================
REM  Win11Debloat launcher - CUSTOM MODE
REM  Opens the script's own menu so you choose what to apply.
REM  Note: this one DOES wait for your input, by design.
REM ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

title Win11Debloat - Custom

echo.
echo Loading Win11Debloat menu...
echo.

REM --- No -RunDefaults or -Silent, so the interactive menu appears ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://debloat.raphi.re/'))) -CreateRestorePoint"

echo.
echo Done. Sign out and back in for all changes to take effect.
