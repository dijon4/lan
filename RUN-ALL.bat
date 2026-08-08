@echo off
setlocal

REM ============================================================
REM  MASTER LAUNCHER
REM  Runs debloat, then the performance settings, back to back.
REM  No keypresses. Closes itself when done.
REM ============================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

title Full Setup

if not exist "%~dp0run-win11debloat.bat" (
    echo ERROR: run-win11debloat.bat not found in this folder.
    exit /b 1
)
if not exist "%~dp0tournament-setup.bat" (
    echo ERROR: tournament-setup.bat not found in this folder.
    exit /b 1
)

echo.
echo ============================================================
echo   STAGE 1 of 2 - Windows cleanup
echo   This takes a few minutes. Leave it alone.
echo ============================================================
echo.

call "%~dp0run-win11debloat.bat"

echo.
echo ============================================================
echo   STAGE 2 of 2 - Performance settings
echo ============================================================
echo.

call "%~dp0tournament-setup.bat"

echo.
echo ============================================================
echo   ALL STAGES COMPLETE
echo ============================================================

endlocal
exit
