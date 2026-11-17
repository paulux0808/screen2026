@echo off
setlocal EnableExtensions
rem ===================================================================
rem  screen2026 board : ONE-TIME SETUP for the PC connected to the TV
rem   1) the board opens by itself in fullscreen whenever Windows starts
rem   2) Chrome/Edge may put the board site into fullscreen without a click
rem   3) the board opens now
rem  Keep start-board.bat in the same folder as this file.
rem  To undo everything: remove-board.bat
rem ===================================================================
set "HERE=%~dp0"
set "APPDIR=%LOCALAPPDATA%\screen2026"
set "ORIGIN=https://paulux0808.github.io"

if not exist "%HERE%start-board.bat" goto missing

rem --- 1. copy the launcher and register it to run at sign-in ---
if not exist "%APPDIR%" mkdir "%APPDIR%"
copy /y "%HERE%start-board.bat" "%APPDIR%\start-board.bat" >nul
set "STARTUP="
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Startup')"`) do set "STARTUP=%%S"
if not defined STARTUP set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
> "%STARTUP%\screen2026-board.bat" echo @start "" /min "%APPDIR%\start-board.bat"
echo  [1/3] The board will open in fullscreen every time Windows starts.

rem --- 2. allow automatic fullscreen for the board site (this user; whole PC too if run as administrator) ---
for %%R in (HKCU HKLM) do (
  reg add "%%R\SOFTWARE\Policies\Google\Chrome\AutomaticFullscreenAllowedForUrls" /v 1 /t REG_SZ /d "%ORIGIN%" /f >nul 2>&1
  reg add "%%R\SOFTWARE\Policies\Microsoft\Edge\AutomaticFullscreenAllowedForUrls" /v 1 /t REG_SZ /d "%ORIGIN%" /f >nul 2>&1
)
echo  [2/3] Chrome/Edge may now open %ORIGIN% in fullscreen without a click.

rem --- 3. open the board now ---
echo  [3/3] Opening the board...
call "%APPDIR%\start-board.bat"
echo.
echo  Done. To close the board window press Alt+F4.
echo  Tip: to stop other programs from starting with Windows, run clean-startup.bat
ping -n 4 127.0.0.1 >nul
exit /b 0

:missing
echo.
echo  [screen2026] start-board.bat must be in the same folder as this file.
echo  Download the whole folder (GitHub: Code - Download ZIP) and unzip it first.
echo.
pause
exit /b 1
