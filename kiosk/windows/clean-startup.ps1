<#
  screen2026 알림판: 이 PC에 로그인할 때 저절로 켜지는 프로그램을 모두 끈다 (알림판만 남긴다).
  - 작업 관리자 → 시작 앱 → '사용 안 함'과 같은 방식이다. 프로그램이나 설정을 지우지 않는다.
  - 되돌리기: restore-startup.bat (이 스크립트를 -Restore 로 실행) 또는 작업 관리자 → 시작 앱 → '사용'.
  - 바꾼 목록은 %LOCALAPPDATA%\screen2026\startup-changes-날짜.json 에 남는다.
  - 직접 실행하지 말고 clean-startup.bat / restore-startup.bat 을 더블클릭한다.
#>
param(
  [string]$UserSid = "",
  [switch]$Restore,
  [switch]$Pause
)
$ErrorActionPreference = "Stop"

# 이름이나 실행 명령에 이 글자가 들어 있으면 끄지 않는다 (알림판, Windows 보안 아이콘)
$Keep = @("screen2026", "SecurityHealth")

$me = [Security.Principal.WindowsIdentity]::GetCurrent()
if(-not $UserSid){ $UserSid = $me.User.Value }
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($me)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$HKU  = "Registry::HKEY_USERS\$UserSid"
$HKLM = "Registry::HKEY_LOCAL_MACHINE"
$CV   = "Software\Microsoft\Windows\CurrentVersion"
$Approved  = "Explorer\StartupApproved"

function Finish([int]$code){
  if($Pause){ Write-Host ""; [void](Read-Host "Enter 를 누르면 창을 닫습니다") }
  exit $code
}

if(-not (Test-Path -LiteralPath $HKU)){
  Write-Host "사용자 설정을 찾지 못했습니다 ($UserSid). 알림판을 띄우는 사용자 계정으로 로그인해서 실행해 주세요."
  Finish 1
}

# 기록을 남길 곳: 그 사용자의 AppData\Local\screen2026
$shellU = Get-ItemProperty -LiteralPath "$HKU\$CV\Explorer\Shell Folders" -ErrorAction SilentlyContinue
$localDir = if($shellU -and $shellU.'Local AppData'){ $shellU.'Local AppData' } else { $env:LOCALAPPDATA }
$logDir = Join-Path $localDir "screen2026"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Test-Kept([string]$name, [string]$cmd){
  foreach($k in $Keep){ if($name -like "*$k*" -or $cmd -like "*$k*"){ return $true } }
  return $false
}

# ───────────────────────────── 되돌리기 ─────────────────────────────
if($Restore){
  $files = @(Get-ChildItem -LiteralPath $logDir -Filter "startup-changes-*.json" -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notlike "*.restored.json" } | Sort-Object Name -Descending)
  if(-not $files.Count){ Write-Host "되돌릴 기록이 없습니다."; Finish 0 }
  foreach($f in $files){
    Write-Host "[$($f.Name)] 되돌리는 중"
    # PowerShell 5.1 은 JSON 배열을 한 덩어리로 넘기므로 변수에 받은 뒤 하나씩 돈다
    $items = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach($c in $items){
      try{
        if($c.kind -eq "dword"){
          if($null -eq $c.old){ Remove-ItemProperty -LiteralPath $c.key -Name $c.name -ErrorAction SilentlyContinue }
          else{ New-ItemProperty -LiteralPath $c.key -Name $c.name -PropertyType DWord -Value ([int]$c.old) -Force | Out-Null }
        }elseif($c.old){
          New-ItemProperty -LiteralPath $c.key -Name $c.name -PropertyType Binary -Value ([Convert]::FromBase64String($c.old)) -Force | Out-Null
        }else{
          Remove-ItemProperty -LiteralPath $c.key -Name $c.name -ErrorAction SilentlyContinue
        }
        Write-Host "  켬    $($c.label)"
      }catch{
        Write-Host "  실패  $($c.label) — $($_.Exception.Message)"
      }
    }
    Rename-Item -LiteralPath $f.FullName -NewName ($f.Name -replace '\.json$', '.restored.json')
  }
  Write-Host ""
  Write-Host "되돌렸습니다. 다음에 로그인할 때부터 원래대로 켜집니다."
  Finish 0
}

# ───────────────────────────── 끄기 ─────────────────────────────
$changes = New-Object System.Collections.ArrayList
$needAdmin = New-Object System.Collections.ArrayList
$failed = New-Object System.Collections.ArrayList
# 작업 관리자가 '사용 안 함'으로 적는 값: 03 00 00 00 + 끈 시각
$offBytes = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()))

function Read-Value([string]$key, [string]$name){
  if(-not (Test-Path -LiteralPath $key)){ return $null }
  return (Get-Item -LiteralPath $key).GetValue($name, $null, "DoNotExpandEnvironmentNames")
}

# 시작 앱 하나를 '사용 안 함'으로 표시한다
function Disable-Startup([string]$approvedKey, [string]$name, [string]$label, [bool]$machine){
  if($machine -and -not $isAdmin){ [void]$needAdmin.Add($label); return }
  try{
    $old = Read-Value $approvedKey $name
    if($old -is [byte[]] -and $old.Length -gt 0 -and ($old[0] % 2) -eq 1){ Write-Host "  (이미 꺼짐) $label"; return }
    if(-not (Test-Path -LiteralPath $approvedKey)){ New-Item -Path $approvedKey -Force | Out-Null }
    New-ItemProperty -LiteralPath $approvedKey -Name $name -PropertyType Binary -Value $offBytes -Force | Out-Null
    $oldText = $null
    if($old -is [byte[]]){ $oldText = [Convert]::ToBase64String($old) }
    [void]$changes.Add([pscustomobject]@{ kind = "binary"; key = $approvedKey; name = $name; old = $oldText; label = $label })
    Write-Host "  끔    $label"
  }catch{
    [void]$failed.Add("$label — $($_.Exception.Message)")
  }
}

Write-Host "로그인할 때 저절로 켜지는 프로그램을 끕니다 (알림판은 그대로 둡니다)"
Write-Host ""

# 1) 레지스트리 Run 항목
$runSources = @(
  @{ run = "$HKU\$CV\Run";  approved = "$HKU\$CV\$Approved\Run";    machine = $false; where = "이 사용자" },
  @{ run = "$HKLM\$CV\Run"; approved = "$HKLM\$CV\$Approved\Run";   machine = $true;  where = "모든 사용자" },
  @{ run = "$HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; approved = "$HKLM\$CV\$Approved\Run32"; machine = $true; where = "모든 사용자, 32비트" }
)
foreach($src in $runSources){
  if(-not (Test-Path -LiteralPath $src.run)){ continue }
  $k = Get-Item -LiteralPath $src.run
  foreach($n in $k.GetValueNames()){
    if(-not $n){ continue }
    $cmd = [string]$k.GetValue($n, "", "DoNotExpandEnvironmentNames")
    if(Test-Kept $n $cmd){ Write-Host "  둠    $n"; continue }
    Disable-Startup $src.approved $n "$n ($($src.where))" $src.machine
  }
}

# 2) 시작프로그램 폴더
$commonShell = Get-ItemProperty -LiteralPath "$HKLM\$CV\Explorer\Shell Folders" -ErrorAction SilentlyContinue
$folders = @(
  @{ dir = $(if($shellU){ $shellU.Startup } else { $null });                 approved = "$HKU\$CV\$Approved\StartupFolder";  machine = $false; where = "이 사용자 시작 폴더" },
  @{ dir = $(if($commonShell){ $commonShell.'Common Startup' } else { $null }); approved = "$HKLM\$CV\$Approved\StartupFolder"; machine = $true;  where = "모든 사용자 시작 폴더" }
)
foreach($f in $folders){
  if(-not $f.dir -or -not (Test-Path -LiteralPath $f.dir)){ continue }
  foreach($file in Get-ChildItem -LiteralPath $f.dir -File -Force -ErrorAction SilentlyContinue){
    if($file.Name -ieq "desktop.ini"){ continue }
    if(Test-Kept $file.Name ""){ Write-Host "  둠    $($file.Name)"; continue }
    Disable-Startup $f.approved $file.Name "$($file.Name) ($($f.where))" $f.machine
  }
}

# 3) 스토어 앱의 시작 작업 (Teams 등). State: 2 = 켜짐 → 1 = 사용자가 끔
$appxRoot = "Registry::HKEY_USERS\$($UserSid)_Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData"
if(Test-Path -LiteralPath $appxRoot){
  foreach($pkg in Get-ChildItem -LiteralPath $appxRoot -ErrorAction SilentlyContinue){
    if(Test-Kept $pkg.PSChildName ""){ continue }
    foreach($task in Get-ChildItem -LiteralPath $pkg.PSPath -ErrorAction SilentlyContinue){
      $state = $task.GetValue("State", $null)
      if($state -ne 2){ continue }
      $label = "$(($pkg.PSChildName -split '_')[0]) (앱)"
      try{
        New-ItemProperty -LiteralPath $task.PSPath -Name "State" -PropertyType DWord -Value 1 -Force | Out-Null
        [void]$changes.Add([pscustomobject]@{ kind = "dword"; key = $task.PSPath; name = "State"; old = 2; label = $label })
        Write-Host "  끔    $label"
      }catch{ [void]$failed.Add("$label — $($_.Exception.Message)") }
    }
  }
}

# 4) '다시 로그인하면 열려 있던 앱을 다시 시작' 끄기
$winlogon = "$HKU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if(Test-Path -LiteralPath $winlogon){
  $old = Read-Value $winlogon "RestartApps"
  if($old -ne 0){
    try{
      New-ItemProperty -LiteralPath $winlogon -Name "RestartApps" -PropertyType DWord -Value 0 -Force | Out-Null
      [void]$changes.Add([pscustomobject]@{ kind = "dword"; key = $winlogon; name = "RestartApps"; old = $old; label = "로그인할 때 열려 있던 앱 다시 열기" })
      Write-Host "  끔    로그인할 때 열려 있던 앱 다시 열기"
    }catch{ [void]$failed.Add("RestartApps — $($_.Exception.Message)") }
  }
}

# 기록 남기기
if($changes.Count){
  $file = Join-Path $logDir ("startup-changes-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")
  ConvertTo-Json -InputObject ([object[]]$changes.ToArray()) -Depth 3 | Set-Content -LiteralPath $file -Encoding UTF8
}

Write-Host ""
Write-Host "끈 것: $($changes.Count)개"
if($needAdmin.Count){
  Write-Host ""
  Write-Host "관리자 권한이 없어 못 끈 것 (모든 사용자용): $($needAdmin.Count)개"
  foreach($x in $needAdmin){ Write-Host "  - $x" }
  Write-Host "  → clean-startup.bat 을 다시 실행해 관리자 확인 창에서 '예'를 누르면 함께 끕니다."
}
if($failed.Count){
  Write-Host ""
  Write-Host "끄지 못한 것:"
  foreach($x in $failed){ Write-Host "  - $x" }
}
Write-Host ""
Write-Host "다음에 로그인할 때부터 알림판만 켜집니다. (이미 켜져 있는 프로그램은 지금 닫히지 않습니다)"
Write-Host "되돌리기: restore-startup.bat  또는  작업 관리자(Ctrl+Shift+Esc) → 시작 앱 → 사용"
Finish 0
