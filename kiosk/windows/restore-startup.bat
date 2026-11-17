@echo off
setlocal EnableExtensions
rem ===================================================================
rem  screen2026 board : undo clean-startup.bat
rem  Turns the startup programs back on, exactly as they were.
rem ===================================================================
if not exist "%~dp0clean-startup.ps1" goto missing
set "SIDARG="
for /f "tokens=2 delims=," %%S in ('whoami /user /fo csv /nh') do set "SIDARG=-UserSid %%~S"

net session >nul 2>&1 && goto run
powershell -NoProfile -Command "Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File \"%~dp0clean-startup.ps1\" -Restore -Pause %SIDARG%')" >nul 2>&1
if errorlevel 1 goto run
exit /b 0

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean-startup.ps1" -Restore -Pause %SIDARG%
exit /b 0

:missing
echo.
echo  [screen2026] clean-startup.ps1 must be in the same folder as this file.
echo.
pause
exit /b 1
