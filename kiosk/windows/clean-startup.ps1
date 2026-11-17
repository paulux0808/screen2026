﻿<#
  screen2026 알림판: 이 PC를 켜고 로그인할 때 저절로 켜지거나 열리는 것을 모두 찾아서 끈다 (알림판만 남긴다).

  찾는 곳 — 작업 관리자 '시작 앱'에 안 나오는 곳까지
    · 시작 앱(레지스트리 Run) · 한 번 실행(RunOnce) · 정책 Run · 옛 방식 Load/Run
    · 시작프로그램 폴더(이 사용자 · 모든 사용자)의 .bat · .html · 바로가기 등
    · 작업 스케줄러: 로그인·부팅 때 도는 작업, 또는 .bat · .html · 브라우저를 여는 작업
    · 로그인 셸(Shell · Userinit)이 다른 프로그램으로 바뀌어 있는 것
    · 스토어 앱(Teams 등) 시작 작업, '다시 로그인하면 열려 있던 앱 다시 열기'
    · 브라우저(Chrome · Edge · 웨일) 정책으로 시작할 때 여는 페이지

  · 먼저 찾은 목록을 보여 주고 묻는다:  Y = 모두 끄기 · S = 하나씩 고르기 · N = 아무것도 하지 않고 닫기
  · 보안 프로그램(V3 · 알약 · NAC 등)으로 보이는 것은 Y 를 눌러도 남긴다(S 로 골라서 끌 수는 있다).
  · 지우지 않는다: 시작 앱은 '사용 안 함' 표시, 작업은 '사용 안 함', 파일은 보관 폴더로 옮기고, 레지스트리 값은 적어 둔 뒤 뺀다.
  · 되돌리기: restore-startup.bat  (이 스크립트를 -Restore 로)
  · 기록: %LOCALAPPDATA%\screen2026\startup-changes-날짜.json   옮긴 파일: %LOCALAPPDATA%\screen2026\startup-backup\날짜\
  · 직접 실행하지 말고 clean-startup.bat / restore-startup.bat 을 더블클릭한다.
#>
param(
  [string]$UserSid = "",
  [switch]$Restore,
  [switch]$Yes,
  [switch]$Pause
)
$ErrorActionPreference = "Stop"

# 이름이나 실행 명령에 이 글자가 들어 있으면 건드리지 않는다 (알림판 · Windows 보안)
$Keep = @("screen2026", "SecurityHealth", "Windows Defender", "MSASCui")
# 보안 프로그램으로 보이는 것: Y 를 눌러도 남긴다
$SecurityHint = 'V3|AhnLab|ALYac|ESTsoft|Hauri|ViRobot|Genian|\bNAC\b|Kaspersky|Norton|McAfee|Avast|\bAVG\b|Bitdefender|ESET|Antivirus|보안|백신'
# 브라우저 자동 업데이트 작업은 남긴다 (보안 패치)
$Updater = 'GoogleUpdate|GoogleUpdater|MicrosoftEdgeUpdate|EdgeUpdate|WhaleUpdate|NaverUpdate'
# 작업 스케줄러에서 '무엇인가 여는' 작업으로 볼 실행 명령
$Launcher = '\.(bat|cmd|vbs|vbe|js|wsf|ps1|hta|html?|url)\b|chrome|msedge|whale|iexplore|firefox|wscript|cscript|mshta'

$me = [Security.Principal.WindowsIdentity]::GetCurrent()
if(-not $UserSid){ $UserSid = $me.User.Value }
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($me)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$HKU  = "Registry::HKEY_USERS\$UserSid"
$HKLM = "Registry::HKEY_LOCAL_MACHINE"
$CV   = "Software\Microsoft\Windows\CurrentVersion"
$Approved = "Explorer\StartupApproved"

function Finish([int]$code){
  if($Pause){ Write-Host ""; [void](Read-Host "Enter 를 누르면 창을 닫습니다") }
  exit $code
}
# 한글 자판 상태로 눌러도 알아듣게: ㅛ=Y ㄴ=S ㅜ=N
function Get-Answer([string]$prompt){
  $a = ([string](Read-Host $prompt)).Trim().ToUpper()
  switch($a){ "ㅛ" { return "Y" } "ㄴ" { return "S" } "ㅜ" { return "N" } default { return $a } }
}
function Shorten([string]$s, [int]$n){ if($s.Length -le $n){ return $s }; return $s.Substring(0, $n - 1) + "…" }

if(-not (Test-Path -LiteralPath $HKU)){
  Write-Host "사용자 설정을 찾지 못했습니다 ($UserSid). 알림판을 띄우는 계정으로 로그인해서 실행해 주세요."
  Finish 1
}

$userFolders = Get-ItemProperty -LiteralPath "$HKU\$CV\Explorer\Shell Folders" -ErrorAction SilentlyContinue
$localDir = if($userFolders -and $userFolders.'Local AppData'){ $userFolders.'Local AppData' } else { $env:LOCALAPPDATA }
$logDir = Join-Path $localDir "screen2026"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

function Read-Value([string]$key, [string]$name){
  if(-not (Test-Path -LiteralPath $key)){ return $null }
  return (Get-Item -LiteralPath $key).GetValue($name, $null, "DoNotExpandEnvironmentNames")
}
function Get-Values([string]$key){
  $out = @()
  if(-not (Test-Path -LiteralPath $key)){ return $out }
  $k = Get-Item -LiteralPath $key
  foreach($n in $k.GetValueNames()){
    if(-not $n){ continue }
    $out += [pscustomobject]@{ Name = $n; Data = $k.GetValue($n, $null, "DoNotExpandEnvironmentNames") }
  }
  return $out
}

# ═════════════════════════════ 되돌리기 ═════════════════════════════
if($Restore){
  $files = @(Get-ChildItem -LiteralPath $logDir -Filter "startup-changes-*.json" -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -notlike "*.restored.json" } | Sort-Object Name -Descending)
  if(-not $files.Count){ Write-Host "되돌릴 기록이 없습니다."; Finish 0 }
  foreach($f in $files){
    Write-Host "[$($f.Name)] 되돌리는 중"
    # PowerShell 5.1 은 JSON 배열을 한 덩어리로 넘기므로 변수에 받은 뒤 하나씩 돈다
    $records = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach($c in $records){
      $type = if($c.type){ $c.type } else { $c.kind }
      try{
        switch($type){
          "binary" {
            if($c.old){ New-ItemProperty -LiteralPath $c.key -Name $c.name -PropertyType Binary -Value ([Convert]::FromBase64String($c.old)) -Force | Out-Null }
            else{ Remove-ItemProperty -LiteralPath $c.key -Name $c.name -ErrorAction SilentlyContinue }
          }
          "dword" {
            if($null -eq $c.old){ Remove-ItemProperty -LiteralPath $c.key -Name $c.name -ErrorAction SilentlyContinue }
            else{ New-ItemProperty -LiteralPath $c.key -Name $c.name -PropertyType DWord -Value ([int]$c.old) -Force | Out-Null }
          }
          "string" {
            if($null -eq $c.old){ Remove-ItemProperty -LiteralPath $c.key -Name $c.name -ErrorAction SilentlyContinue }
            else{ New-ItemProperty -LiteralPath $c.key -Name $c.name -PropertyType String -Value ([string]$c.old) -Force | Out-Null }
          }
          "deleted" {
            if(-not (Test-Path -LiteralPath $c.key)){ New-Item -Path $c.key -Force | Out-Null }
            $v = $c.data
            switch($c.vkind){
              "Binary"      { $v = [Convert]::FromBase64String([string]$c.data) }
              "DWord"       { $v = [int]$c.data }
              "QWord"       { $v = [long]$c.data }
              "MultiString" { $v = [string[]]@($c.data) }
              default       { $v = [string]$c.data }
            }
            New-ItemProperty -LiteralPath $c.key -Name $c.name -PropertyType $c.vkind -Value $v -Force | Out-Null
          }
          "moved" {
            if(Test-Path -LiteralPath $c.to){
              $dir = Split-Path -Parent $c.from
              if(-not (Test-Path -LiteralPath $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
              Move-Item -LiteralPath $c.to -Destination $c.from -Force
            }
          }
          "task" { Enable-ScheduledTask -TaskPath $c.path -TaskName $c.name | Out-Null }
        }
        Write-Host "  켬    $($c.label)" -ForegroundColor Green
      }catch{
        Write-Host "  실패  $($c.label) — $($_.Exception.Message)" -ForegroundColor Red
      }
    }
    Rename-Item -LiteralPath $f.FullName -NewName ($f.Name -replace '\.json$', '.restored.json')
  }
  Write-Host ""
  Write-Host "되돌렸습니다. 다음에 로그인할 때부터 원래대로 켜집니다."
  Finish 0
}

# ═════════════════════════════ 찾기 ═════════════════════════════
$items = New-Object System.Collections.ArrayList
$kept = New-Object System.Collections.ArrayList
$reports = New-Object System.Collections.ArrayList

function Test-Kept([string]$text){ foreach($k in $Keep){ if($text -like "*$k*"){ return $true } }; return $false }
function Add-Item([string]$kind, [string]$where, [string]$label, [string]$detail, [bool]$admin, $data){
  if(Test-Kept "$label $detail"){ [void]$kept.Add("$label ($where)"); return }
  [void]$items.Add([pscustomobject]@{
    Kind = $kind; Where = $where; Label = $label; Detail = $detail; Admin = $admin
    Security = [bool]("$label $detail" -match $SecurityHint); Data = $data
  })
}
function Get-LinkTarget([string]$path){
  try{ $l = (New-Object -ComObject WScript.Shell).CreateShortcut($path); return ("$($l.TargetPath) $($l.Arguments)").Trim() }catch{ return "" }
}

Write-Host "로그인할 때 저절로 켜지거나 열리는 것을 찾는 중…"
Write-Host ""

# 1) 시작 앱 (레지스트리 Run) — 작업 관리자 '시작 앱'에 보이는 것
$runSources = @(
  @{ key = "$HKU\$CV\Run";  approved = "$HKU\$CV\$Approved\Run";  admin = $false; where = "시작 앱 · 이 사용자" },
  @{ key = "$HKLM\$CV\Run"; approved = "$HKLM\$CV\$Approved\Run"; admin = $true;  where = "시작 앱 · 모든 사용자" },
  @{ key = "$HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"; approved = "$HKLM\$CV\$Approved\Run32"; admin = $true; where = "시작 앱 · 모든 사용자(32비트)" }
)
foreach($s in $runSources){
  foreach($v in Get-Values $s.key){
    $cur = Read-Value $s.approved $v.Name
    if($cur -is [byte[]] -and $cur.Length -gt 0 -and ($cur[0] % 2) -eq 1){ continue }      # 이미 꺼져 있다
    Add-Item "approved" $s.where $v.Name ([string]$v.Data) $s.admin @{ approved = $s.approved; name = $v.Name }
  }
}

# 2) 한 번 실행 · 정책 Run (작업 관리자에 안 보임)
$valueSources = @(
  @{ key = "$HKU\$CV\RunOnce";  admin = $false; where = "한 번 실행(RunOnce) · 이 사용자" },
  @{ key = "$HKLM\$CV\RunOnce"; admin = $true;  where = "한 번 실행(RunOnce) · 모든 사용자" },
  @{ key = "$HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce"; admin = $true; where = "한 번 실행(RunOnce) · 모든 사용자(32비트)" },
  @{ key = "$HKU\$CV\Policies\Explorer\Run";  admin = $false; where = "정책 Run · 이 사용자 (작업 관리자에 안 보임)" },
  @{ key = "$HKLM\$CV\Policies\Explorer\Run"; admin = $true;  where = "정책 Run · 모든 사용자 (작업 관리자에 안 보임)" }
)
foreach($s in $valueSources){
  foreach($v in Get-Values $s.key){ Add-Item "value" $s.where $v.Name ([string]$v.Data) $s.admin @{ key = $s.key; name = $v.Name } }
}
# 옛 방식 Load / Run
$legacy = "$HKU\Software\Microsoft\Windows NT\CurrentVersion\Windows"
foreach($n in @("Load", "Run")){
  $d = [string](Read-Value $legacy $n)
  if($d.Trim()){ Add-Item "value" "옛 방식 $n · 이 사용자 (작업 관리자에 안 보임)" $n $d $false @{ key = $legacy; name = $n } }
}

# 3) 시작프로그램 폴더 — .bat · .html · 바로가기 등 그 안의 모든 파일
$commonFolders = Get-ItemProperty -LiteralPath "$HKLM\$CV\Explorer\Shell Folders" -ErrorAction SilentlyContinue
$folders = @(
  @{ dir = $(if($userFolders){ $userFolders.Startup } else { $null });                     admin = $false; where = "시작프로그램 폴더 · 이 사용자";   tag = "user" },
  @{ dir = $(if($commonFolders){ $commonFolders.'Common Startup' } else { $null });        admin = $true;  where = "시작프로그램 폴더 · 모든 사용자"; tag = "common" }
)
foreach($f in $folders){
  if(-not $f.dir -or -not (Test-Path -LiteralPath $f.dir)){ continue }
  foreach($file in Get-ChildItem -LiteralPath $f.dir -Force -ErrorAction SilentlyContinue){
    if($file.Name -ieq "desktop.ini"){ continue }
    $detail = $file.FullName
    if($file.Extension -ieq ".lnk"){ $t = Get-LinkTarget $file.FullName; if($t){ $detail = $t } }
    Add-Item "file" $f.where $file.Name $detail $f.admin @{ path = $file.FullName; tag = $f.tag }
  }
}

# 4) 작업 스케줄러 (작업 관리자에 안 보임) — 로그인·부팅 때 도는 작업, 또는 무엇인가 여는 작업. Windows 자체 작업(\Microsoft\)은 빼고
$tasks = @()
try{ $tasks = @(Get-ScheduledTask -ErrorAction Stop) }catch{ [void]$reports.Add("작업 스케줄러를 읽지 못했습니다: $($_.Exception.Message)") }
foreach($t in $tasks){
  if(-not $t -or $t.TaskPath -like "\Microsoft\*" -or "$($t.State)" -eq "Disabled"){ continue }
  $acts = (@($t.Actions) | Where-Object { $_ } | ForEach-Object { ("$($_.Execute) $($_.Arguments)").Trim() }) -join " ; "
  $trig = @(@($t.Triggers) | Where-Object { $_ } | ForEach-Object { $_.CimClass.CimClassName })
  $atStart = @($trig | Where-Object { $_ -eq "MSFT_TaskLogonTrigger" -or $_ -eq "MSFT_TaskBootTrigger" }).Count -gt 0
  if(-not $atStart -and $acts -notmatch $Launcher){ continue }
  if("$($t.TaskName) $acts" -match $Updater){ continue }
  $when = if($atStart){ "로그인·부팅할 때" } else { "정해진 때" }
  Add-Item "task" "작업 스케줄러 · $when (작업 관리자에 안 보임)" "$($t.TaskPath)$($t.TaskName)" $acts $true @{ path = $t.TaskPath; name = $t.TaskName }
}

# 5) 로그인 셸이 바뀌어 있는 것 (작업 관리자에 안 보임)
$wlM = "$HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
$wlU = "$HKU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
$shellM = [string](Read-Value $wlM "Shell")
if($shellM.Trim() -and $shellM.Trim() -ine "explorer.exe"){
  Add-Item "setstring" "로그인 셸 · 모든 사용자 (작업 관리자에 안 보임) → explorer.exe 로 되돌림" "Shell" $shellM $true @{ key = $wlM; name = "Shell"; value = "explorer.exe" }
}
$shellUser = [string](Read-Value $wlU "Shell")
if($shellUser.Trim() -and $shellUser.Trim() -ine "explorer.exe"){
  Add-Item "value" "로그인 셸 · 이 사용자 (작업 관리자에 안 보임) → 기본값으로 되돌림" "Shell" $shellUser $false @{ key = $wlU; name = "Shell" }
}
$userinit = [string](Read-Value $wlM "Userinit")
$extra = @($userinit -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '(^|\\)userinit\.exe$' })
if($extra.Count){
  Add-Item "setstring" "로그인할 때 함께 실행(Userinit) · 모든 사용자 (작업 관리자에 안 보임)" "Userinit" ($extra -join ", ") $true @{ key = $wlM; name = "Userinit"; value = "$env:SystemRoot\system32\userinit.exe," }
}

# 6) 스토어 앱 시작 작업 (Teams 등). State 2 = 켜짐 → 1 = 사용자가 끔
$appxRoot = "Registry::HKEY_USERS\$($UserSid)_Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData"
if(Test-Path -LiteralPath $appxRoot){
  foreach($pkg in Get-ChildItem -LiteralPath $appxRoot -ErrorAction SilentlyContinue){
    foreach($task in Get-ChildItem -LiteralPath $pkg.PSPath -ErrorAction SilentlyContinue){
      if($task.GetValue("State", $null) -ne 2){ continue }
      Add-Item "dword" "스토어 앱 시작 작업 · 이 사용자" (($pkg.PSChildName -split '_')[0]) $task.PSChildName $false @{ key = $task.PSPath; name = "State"; value = 1 }
    }
  }
}

# 7) '다시 로그인하면 열려 있던 앱 다시 열기'
$winlogonUser = "$HKU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
if((Test-Path -LiteralPath $winlogonUser) -and (Read-Value $winlogonUser "RestartApps") -ne 0){
  Add-Item "dword" "Windows 설정 · 이 사용자" "로그인할 때 열려 있던 앱 다시 열기" "" $false @{ key = $winlogonUser; name = "RestartApps"; value = 0 }
}

# 8) 브라우저 정책: 시작할 때 여는 페이지 (알림판 키오스크 창에도 끼어들 수 있다)
$browsers = @(@{ name = "Chrome"; path = "Google\Chrome" }, @{ name = "Edge"; path = "Microsoft\Edge" }, @{ name = "웨일"; path = "Naver\Whale" })
foreach($root in @(@{ hive = $HKLM; who = "모든 사용자" }, @{ hive = $HKU; who = "이 사용자" })){
  foreach($b in $browsers){
    $pk = "$($root.hive)\Software\Policies\$($b.path)"
    $urlsKey = "$pk\RestoreOnStartupURLs"
    $urls = @(Get-Values $urlsKey)
    if($null -ne (Read-Value $pk "RestoreOnStartup") -or $urls.Count){
      $detail = (@($urls) | ForEach-Object { [string]$_.Data }) -join ", "
      Add-Item "policy" "브라우저 정책 · $($root.who) (작업 관리자에 안 보임)" "$($b.name) 시작할 때 여는 페이지" $detail $true @{ key = $pk; urlsKey = $urlsKey }
    }
  }
}

# 9) 그룹 정책 로그온·시작 스크립트 — 자동으로 끄지 않고 알려만 준다
foreach($p in @("$env:SystemRoot\System32\GroupPolicy\User\Scripts\scripts.ini", "$env:SystemRoot\System32\GroupPolicy\Machine\Scripts\scripts.ini")){
  try{
    if(Test-Path -LiteralPath $p){
      foreach($line in Get-Content -LiteralPath $p -Encoding Unicode -ErrorAction Stop){
        if($line -match '^\s*\d+CmdLine\s*=\s*(.+)$'){ [void]$reports.Add("그룹 정책 스크립트: $($Matches[1])  (gpedit.msc → 사용자/컴퓨터 구성 → Windows 설정 → 스크립트)") }
      }
    }
  }catch{}
}
foreach($k in @("$HKU\$CV\Group Policy\Scripts\Logon", "$HKLM\$CV\Group Policy\Scripts\Startup")){
  if(Test-Path -LiteralPath $k){
    foreach($sub in Get-ChildItem -LiteralPath $k -Recurse -ErrorAction SilentlyContinue){
      $sc = $sub.GetValue("Script", $null)
      if($sc){ [void]$reports.Add("그룹 정책 스크립트: $sc  (학교·교육청 정책이면 담당자에게 문의)") }
    }
  }
}

# ═════════════════════════════ 보여 주고 묻기 ═════════════════════════════
if($kept.Count){
  Write-Host "그대로 둘 것 (알림판 · Windows 보안):" -ForegroundColor Cyan
  foreach($x in $kept){ Write-Host "  - $x" }
  Write-Host ""
}
if($reports.Count){
  Write-Host "직접 확인할 것 (자동으로 끄지 않음):" -ForegroundColor Yellow
  foreach($x in ($reports | Select-Object -Unique)){ Write-Host "  - $x" }
  Write-Host ""
}
if(-not $items.Count){
  Write-Host "끌 것이 없습니다. 로그인할 때 따로 켜지는 것이 없습니다."
  Finish 0
}
Write-Host "로그인할 때 저절로 켜지거나 열리는 것: $($items.Count)개" -ForegroundColor White
Write-Host ""
$i = 0
foreach($it in $items){
  $i++
  Write-Host ("[{0,2}] {1}" -f $i, $it.Label) -ForegroundColor White
  Write-Host ("     {0}" -f $it.Where)
  if($it.Detail){ Write-Host ("     → {0}" -f (Shorten $it.Detail 110)) -ForegroundColor DarkGray }
  if($it.Security){ Write-Host "     ※ 보안 프로그램으로 보입니다. Y 를 눌러도 남깁니다(S 로 골라서 끌 수 있음)." -ForegroundColor Yellow }
  if($it.Admin -and -not $isAdmin){ Write-Host "     ※ 관리자 권한이 있어야 끌 수 있습니다." -ForegroundColor Yellow }
}
Write-Host ""
$choice = if($Yes){ "Y" } else { Get-Answer "Y = 모두 끄기 · S = 하나씩 고르기 · N = 아무것도 하지 않고 닫기" }
$selected = @()
if($choice -eq "Y"){
  $selected = @($items | Where-Object { -not $_.Security })
}elseif($choice -eq "S"){
  $i = 0
  foreach($it in $items){
    $i++
    $a = Get-Answer ("[{0,2}] {1} — 끌까요? (Y/N)" -f $i, $it.Label)
    if($a -eq "Y"){ $selected += $it }
  }
}else{
  Write-Host "아무것도 바꾸지 않았습니다."
  Finish 0
}

# ═════════════════════════════ 끄기 ═════════════════════════════
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logDir "startup-changes-$stamp.json"
$backupDir = Join-Path $logDir "startup-backup\$stamp"
$changes = New-Object System.Collections.ArrayList
$needAdmin = New-Object System.Collections.ArrayList
$failed = New-Object System.Collections.ArrayList
# 작업 관리자가 '사용 안 함'으로 적는 값: 03 00 00 00 + 끈 시각
$offBytes = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()))

# 바꿀 때마다 바로 기록한다 (도중에 멈춰도 되돌릴 수 있게)
function Add-Change($h){
  [void]$changes.Add([pscustomobject]$h)
  ConvertTo-Json -InputObject ([object[]]$changes.ToArray()) -Depth 5 | Set-Content -LiteralPath $logFile -Encoding UTF8
}
function Remove-ValueRecorded([string]$key, [string]$name, [string]$label){
  if(-not (Test-Path -LiteralPath $key)){ return }
  $k = Get-Item -LiteralPath $key
  if($k.GetValueNames() -notcontains $name){ return }
  $vk = $k.GetValueKind($name).ToString()
  $data = $k.GetValue($name, $null, "DoNotExpandEnvironmentNames")
  if($data -is [byte[]]){ $data = [Convert]::ToBase64String($data) }
  Remove-ItemProperty -LiteralPath $key -Name $name
  Add-Change @{ type = "deleted"; key = $key; name = $name; vkind = $vk; data = $data; label = $label }
}

Write-Host ""
foreach($it in $selected){
  if($it.Admin -and -not $isAdmin){ [void]$needAdmin.Add($it.Label); continue }
  $d = $it.Data
  try{
    switch($it.Kind){
      "approved" {
        $old = Read-Value $d.approved $d.name
        if(-not (Test-Path -LiteralPath $d.approved)){ New-Item -Path $d.approved -Force | Out-Null }
        New-ItemProperty -LiteralPath $d.approved -Name $d.name -PropertyType Binary -Value $offBytes -Force | Out-Null
        $oldText = $null
        if($old -is [byte[]]){ $oldText = [Convert]::ToBase64String($old) }
        Add-Change @{ type = "binary"; key = $d.approved; name = $d.name; old = $oldText; label = $it.Label }
      }
      "value" { Remove-ValueRecorded $d.key $d.name $it.Label }
      "policy" {
        Remove-ValueRecorded $d.key "RestoreOnStartup" $it.Label
        foreach($v in Get-Values $d.urlsKey){ Remove-ValueRecorded $d.urlsKey $v.Name $it.Label }
      }
      "file" {
        $dest = Join-Path (Join-Path $backupDir $d.tag) (Split-Path -Leaf $d.path)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Move-Item -LiteralPath $d.path -Destination $dest -Force
        Add-Change @{ type = "moved"; from = $d.path; to = $dest; label = $it.Label }
      }
      "task" {
        Disable-ScheduledTask -TaskPath $d.path -TaskName $d.name | Out-Null
        Add-Change @{ type = "task"; path = $d.path; name = $d.name; label = $it.Label }
      }
      "setstring" {
        $old = Read-Value $d.key $d.name
        New-ItemProperty -LiteralPath $d.key -Name $d.name -PropertyType String -Value $d.value -Force | Out-Null
        Add-Change @{ type = "string"; key = $d.key; name = $d.name; old = $old; label = $it.Label }
      }
      "dword" {
        $old = Read-Value $d.key $d.name
        New-ItemProperty -LiteralPath $d.key -Name $d.name -PropertyType DWord -Value ([int]$d.value) -Force | Out-Null
        Add-Change @{ type = "dword"; key = $d.key; name = $d.name; old = $old; label = $it.Label }
      }
    }
    Write-Host "  끔    $($it.Label)" -ForegroundColor Green
  }catch{
    [void]$failed.Add("$($it.Label) — $($_.Exception.Message)")
  }
}

Write-Host ""
Write-Host "끈 것: $(@($selected).Count - $needAdmin.Count - $failed.Count)개" -ForegroundColor White
if($needAdmin.Count){
  Write-Host ""
  Write-Host "관리자 권한이 없어 못 끈 것: $($needAdmin.Count)개" -ForegroundColor Yellow
  foreach($x in $needAdmin){ Write-Host "  - $x" }
  Write-Host "  → clean-startup.bat 을 다시 실행해 관리자 확인 창에서 '예'를 누르면 함께 끕니다."
}
if($failed.Count){
  Write-Host ""
  Write-Host "끄지 못한 것:" -ForegroundColor Red
  foreach($x in $failed){ Write-Host "  - $x" }
}
if(-not @($kept | Where-Object { $_ -like "*screen2026*" }).Count){
  Write-Host ""
  Write-Host "※ 알림판 자동 시작이 아직 설정돼 있지 않습니다. setup-board.bat 을 실행해 주세요." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "PC를 다시 시작하면 알림판만 뜹니다. (지금 떠 있는 프로그램은 닫지 않습니다)"
Write-Host "되돌리기: restore-startup.bat"
if($changes.Count){ Write-Host "기록: $logFile" -ForegroundColor DarkGray }
Finish 0
