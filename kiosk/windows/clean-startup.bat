@echo off
setlocal EnableExtensions
rem ===================================================================
rem  screen2026 board : turn OFF every program that starts by itself
rem  when someone signs in to this PC. The board (screen2026) stays on.
rem  - Same as Task Manager > Startup apps > Disable. Nothing is deleted.
rem  - Undo: restore-startup.bat  (or Task Manager > Startup apps > Enable)
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
