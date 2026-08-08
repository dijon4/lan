@echo off
setlocal

REM ============================================================
REM  MASTER LAUNCHER
REM  Runs the debloat script, then the tournament setup script.
REM  Elevates ONCE - the child scripts inherit admin rights.
REM
REM  All three .bat files must sit in the same folder.
REM ============================================================

REM --- Elevate once, up front ---
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1
    exit /b
)

title Full Setup

REM --- Check both scripts are present before starting ---
if not exist "%~dp0run-win11debloat.bat" (
    echo ERROR: run-win11debloat.bat not found in this folder.
    pause
    exit /b 1
)
if not exist "%~dp0tournament-setup.bat" (
    echo ERROR: tournament-setup.bat not found in this folder.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   STAGE 1 of 2 - Debloat
echo   This takes a few minutes. Leave it alone.
echo ============================================================
echo.

REM  "call" waits for the script to finish before moving on.
REM  Without it, the second script would start immediately.
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
echo   Sign out and back in for the debloat changes to finish.
echo ============================================================
echo.
pause

endlocal
