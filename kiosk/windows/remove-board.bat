@echo off
setlocal EnableExtensions
rem ===================================================================
rem  screen2026 board : undo setup-board.bat
rem   - stop opening the board at Windows start
rem   - remove the "fullscreen without a click" permission
rem   - close the board window
rem ===================================================================
set "APPDIR=%LOCALAPPDATA%\screen2026"
set "STARTUP="
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Startup')"`) do set "STARTUP=%%S"
if not defined STARTUP set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

del /q "%STARTUP%\screen2026-board.bat" >nul 2>&1
for %%R in (HKCU HKLM) do (
  reg delete "%%R\SOFTWARE\Policies\Google\Chrome\AutomaticFullscreenAllowedForUrls" /v 1 /f >nul 2>&1
  reg delete "%%R\SOFTWARE\Policies\Microsoft\Edge\AutomaticFullscreenAllowedForUrls" /v 1 /f >nul 2>&1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'chrome.exe' -or $_.Name -eq 'msedge.exe') -and $_.CommandLine -like '*screen2026-kiosk*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1
rmdir /s /q "%APPDIR%" >nul 2>&1

echo.
echo  [screen2026] Removed. The board will no longer open by itself.
echo.
pause
