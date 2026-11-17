@echo off
setlocal EnableExtensions
rem ===================================================================
rem  screen2026 board : find and turn OFF everything that starts or opens
rem  by itself when someone signs in to this PC. The board stays on.
rem  Looks beyond Task Manager: Task Scheduler jobs, .bat/.html files in
rem  Startup folders, RunOnce / policy Run keys, a replaced login shell,
rem  and browser "pages to open at startup" policies.
rem  - Shows the list first, then asks: Y = all, S = one by one, N = cancel
rem  - Nothing is deleted: undo with restore-startup.bat
rem  - Keep clean-startup.ps1 in the same folder as this file.
rem ===================================================================
if not exist "%~dp0clean-startup.ps1" goto missing
set "SIDARG="
for /f "tokens=2 delims=," %%S in ('whoami /user /fo csv /nh') do set "SIDARG=-UserSid %%~S"

rem Ask for administrator rights once (needed for programs set up for all users).
rem If the answer is No, only this user's programs are turned off.
net session >nul 2>&1 && goto run
powershell -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File \"%~dp0clean-startup.ps1\" -Pause %SIDARG%')" >nul 2>&1
if errorlevel 1 goto run
exit /b 0

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean-startup.ps1" -Pause %SIDARG%
exit /b 0

:missing
echo.
echo  [screen2026] clean-startup.ps1 must be in the same folder as this file.
echo.
pause
exit /b 1
