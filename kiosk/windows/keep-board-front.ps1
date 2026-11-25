<#
  screen2026 board : keep the board window on top for the first few minutes.

  Right after Windows starts, other start-up windows (for example an auto-shutdown
  PowerShell window) can open AFTER the board and cover it. For -Minutes minutes
  this script puts the board window "always on top" every -Every seconds, then
  turns "always on top" off again (the board stays in front).

  Started by start-board.bat (hidden). Do not run it by hand.
  -ProcessNames / -Match are only for testing.
#>
param(
  [double]$Minutes = 5,
  [int]$Every = 3,
  [string[]]$ProcessNames = @("chrome.exe", "msedge.exe"),
  [string]$Match = "*screen2026-kiosk*"
)
$ErrorActionPreference = "SilentlyContinue"

Add-Type -Namespace Screen2026 -Name Win -MemberDefinition @"
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
"@
$TOPMOST = [IntPtr](-1)
$NOTOPMOST = [IntPtr](-2)
$FLAGS = [uint32](0x0001 -bor 0x0002 -bor 0x0010 -bor 0x0040)   # NOSIZE | NOMOVE | NOACTIVATE | SHOWWINDOW

# the visible top-level window of the board browser (not the other Chrome/Edge windows)
function Get-BoardWindows {
  $found = @()
  $procs = Get-CimInstance Win32_Process | Where-Object { $ProcessNames -contains $_.Name -and $_.CommandLine -like $Match }
  foreach ($p in $procs) {
    $h = (Get-Process -Id $p.ProcessId).MainWindowHandle
    if ($h -and $h -ne [IntPtr]::Zero -and [Screen2026.Win]::IsWindowVisible($h)) { $found += $h }
  }
  $found
}

$deadline = (Get-Date).AddMinutes($Minutes)
$seen = @{}
while ((Get-Date) -lt $deadline) {
  foreach ($h in Get-BoardWindows) {
    [void][Screen2026.Win]::SetWindowPos($h, $TOPMOST, 0, 0, 0, 0, $FLAGS)
    $seen["$h"] = $h
  }
  Start-Sleep -Seconds $Every
}

# done: back to a normal window, still in front of the windows that opened meanwhile
foreach ($h in $seen.Values) { [void][Screen2026.Win]::SetWindowPos($h, $NOTOPMOST, 0, 0, 0, 0, $FLAGS) }
