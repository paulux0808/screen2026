@echo off
setlocal EnableExtensions
rem ===================================================================
rem  screen2026 board : open the board in FULLSCREEN (kiosk) mode
rem  - Double-click this file. The board fills the whole screen.
rem  - To close the board window: press Alt+F4.
rem  - If the board address changes, edit BOARD_URL below.
rem ===================================================================
set "BOARD_URL=https://paulux0808.github.io/screen2026/"
set "PROFILE_DIR=%LOCALAPPDATA%\screen2026-kiosk"

rem --- 1. find a browser (Chrome first, then Edge) ---
set "BROWSER="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "BROWSER=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" set "BROWSER=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
if not defined BROWSER if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "BROWSER=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined BROWSER if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "BROWSER=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not defined BROWSER goto nobrowser

rem --- 2. close a board window that is already open (only the board, not other browser windows) ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { ($_.Name -eq 'chrome.exe' -or $_.Name -eq 'msedge.exe') -and $_.CommandLine -like '*screen2026-kiosk*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1

rem --- 3. right after the PC starts, wait up to 30 seconds for the internet ---
where curl.exe >nul 2>&1 || goto launch
set /a TRIES=0
:waitnet
curl.exe -s -o nul -m 5 -I "%BOARD_URL%" >nul 2>&1 && goto launch
set /a TRIES+=1
if %TRIES% GEQ 6 goto launch
ping -n 6 127.0.0.1 >nul
goto waitnet

rem --- 4. open the board as a fullscreen kiosk window ---
:launch
set "EXTRA="
if /i not "%BROWSER:msedge=%"=="%BROWSER%" set "EXTRA=--edge-kiosk-type=fullscreen"
start "" "%BROWSER%" --kiosk "%BOARD_URL%" %EXTRA% --user-data-dir="%PROFILE_DIR%" --no-first-run --no-default-browser-check --disable-session-crashed-bubble --hide-crash-restore-bubble --noerrdialogs --disable-features=Translate --overscroll-history-navigation=0 --disable-pinch
exit /b 0

:nobrowser
echo.
echo  [screen2026] Google Chrome or Microsoft Edge was not found.
echo  Install Google Chrome, then run this file again.
echo.
pause
exit /b 1
