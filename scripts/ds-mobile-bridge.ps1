# DSH Mobile 自动隧道 / 访问地址监视器 (v4)
#  1) 桌面重启后若之前开过隧道 → 自动重新开启(手机不在线时)；
#  2) 隧道 URL 变化 → 推送新链接到手机；
#  3) 局域网 IP 变化 → 也推送新地址到手机(避免换了 IP 手机打不开)；
#  4) 持续写 ds-mobile-url.txt 与 ds-mobile-bridge.log。
param([switch]$Once)
$ErrorActionPreference = 'SilentlyContinue'
$cfgDir   = if ($env:DSH_MOBILE_DIR) { $env:DSH_MOBILE_DIR } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$statePath= "$cfgDir/ds-mobile-state.json"
$urlPath  = "$cfgDir/ds-mobile-url.txt"
$keyPath  = "$cfgDir/ds-phone-notify.json"
$logPath  = "$cfgDir/ds-mobile-bridge.log"
$GW_PORT  = 43127
$Base     = "http://127.0.0.1:$GW_PORT"

$self = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'ds-mobile-bridge\.ps1' -and $_.ProcessId -ne $PID }
if ($self) { Write-Output 'another instance running; exit'; exit 0 }

function Log-Msg($m) { try { Add-Content -LiteralPath $logPath -Value ("[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "] " + $m) -Encoding UTF8 } catch {} }
function Read-State { try { Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath | ConvertFrom-Json } catch { $null } }
function Write-State($obj) { try { [System.IO.File]::WriteAllText($statePath, ($obj | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false))) } catch {} }
# 用 curl.exe 做本机 HTTP（跨 PowerShell 5.1/7 都可靠，且显式绕过系统代理）
function Get-Json($path) {
  try {
    $out = (& curl.exe -s --noproxy "*" --max-time 10 ($Base + $path) 2>$null | Out-String).Trim()
    if (-not $out) { return $null }
    return ($out | ConvertFrom-Json)
  } catch { return $null }
}
function Post-Json($path, $obj) {
  try {
    $body = $obj | ConvertTo-Json -Compress
    $out = (& curl.exe -s --noproxy "*" --max-time 20 -X POST -H "Content-Type: application/json" -d $body ($Base + $path) 2>$null | Out-String).Trim()
    Log-Msg "post $path -> $out"
    if (-not $out) { return $null }
    return ($out | ConvertFrom-Json)
  } catch { Log-Msg "post $path failed: $($_.Exception.Message)"; return $null }
}
function Gateway-Pid { $c = Get-NetTCPConnection -LocalPort $GW_PORT -State Listen -ErrorAction SilentlyContinue; if ($c) { $c[0].OwningProcess } else { $null } }
function Lan-Url {
  # 只取“有默认网关”的真实网卡地址（手机可达），避免误选 WSL/Hyper-V/Wi-Fi Direct 等虚拟网卡
  $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceAlias -notmatch 'Tailscale' } |
        Sort-Object RouteMetric | Select-Object -First 1
  if ($gw) {
    $ip = (Get-NetIPAddress -InterfaceIndex $gw.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
           Where-Object { $_.IPAddress -notmatch '^169\.254' -and $_.IPAddress -notmatch '^127\.' } | Select-Object -First 1).IPAddress
    if ($ip) { return "http://$ip`:$GW_PORT" }
  }
  $item = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
          Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.254' -and $_.InterfaceAlias -notmatch 'Tailscale' } |
          Sort-Object SkipAsSource, InterfaceMetric | Select-Object -First 1
  if ($item) { "http://$($item.IPAddress):$GW_PORT" } else { '' }
}
function Tailnet-Url {
  $tsExe = $null
  $cmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
  if ($cmd) { $tsExe = $cmd.Source }
  elseif (Test-Path 'C:/Program Files/Tailscale/tailscale.exe') { $tsExe = 'C:/Program Files/Tailscale/tailscale.exe' }
  if (-not $tsExe) { return '' }
  try { $ip = (& $tsExe ip -4 2>$null | Select-Object -First 1).Trim(); if ($ip) { "http://$ip`:$GW_PORT" } else { '' } } catch { '' }
}
function Push-Msg($title, $body, $url) {
  try { $cfg = Get-Content -Raw -Encoding UTF8 -LiteralPath $keyPath | ConvertFrom-Json } catch { return }
  if (-not $cfg.barkKey) { Log-Msg "push-skip(no barkKey) title=$title"; return }
  $p = @{ device_key = $cfg.barkKey; title = $title; body = $body; group = 'DSH' }
  if ($url) { $p.url = $url }
  $json = $p | ConvertTo-Json -Compress
  $tmp = Join-Path $env:TEMP ('ds-murl-' + [guid]::NewGuid().ToString('N') + '.json')
  try { [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false))) } catch { return }
  $resp = (& curl.exe -s -m 15 --noproxy "*" -X POST 'https://api.day.app/push' -H 'Content-Type: application/json; charset=utf-8' --data-binary "@$tmp" 2>&1 | Out-String).Trim()
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  Log-Msg "push title=$title url=$url resp=$resp"
}

Log-Msg "monitor v4 start pid=$PID"
$state = Read-State
if (-not $state) { $state = [pscustomobject]@{ lastGatewayPid=$null; tunnelDesired=$true; lastTunnelUrl=''; lastToggleAt=$null; toggleAttempts=0; lastLanUrl='' } }
foreach ($f in 'lastGatewayPid','tunnelDesired','lastTunnelUrl','lastToggleAt','toggleAttempts','lastLanUrl') {
  if ($null -eq $state.$f -and $f -notin 'lastToggleAt') { $state | Add-Member -NotePropertyName $f -NotePropertyValue '' -Force }
}

for (;;) {
  $gwPid = Gateway-Pid
  if (-not $gwPid) {
    if ($state.lastGatewayPid) { Log-Msg "gateway down (was pid=$($state.lastGatewayPid))"; $state.lastGatewayPid=$null; Write-State $state }
    if ($Once) { break }
    Start-Sleep -Seconds 8; continue
  }
  $restarted = ($state.lastGatewayPid -ne $gwPid)
  if ($restarted) { Log-Msg "desktop(gateway) detected pid=$gwPid (previous=$($state.lastGatewayPid))"; $state.lastGatewayPid=$gwPid }

  $status = Get-Json '/desktop/tunnel/status'
  $conn   = Get-Json '/desktop/status'
  $connected = ($conn -and $conn.connected)
  $active    = ($status -and $status.active)
  $loading   = ($status -and $status.loading)
  $turl      = if ($status.url) { $status.url } else { '' }

  $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if ($state.tunnelDesired -and $restarted -and -not $active -and -not $loading -and -not $connected) {
    $lastAt = if ($state.lastToggleAt) { [int64]$state.lastToggleAt } else { 0 }
    if ($null -eq $state.lastToggleAt -or $nowMs - $lastAt -gt 90000) {
      $state.toggleAttempts = [int]$state.toggleAttempts + 1
      $state.lastToggleAt = $nowMs
      if ($state.toggleAttempts -le 4) {
        Log-Msg "auto-enable tunnel attempt $($state.toggleAttempts)"
        $null = Post-Json '/desktop/tunnel/toggle' @{ enable = $true }
      } else { Log-Msg 'auto-enable giving up (retry next restart)' }
    }
  }
  if ($active) { $state.toggleAttempts = 0; $state.lastToggleAt = $null }

  $lan = Lan-Url
  $best = ''
  if ($active -and $turl) { $best = $turl }
  if (-not $best) { $best = Tailnet-Url }
  if (-not $best) { $best = $lan }
  if ($best) { try { [System.IO.File]::WriteAllText($urlPath, $best, (New-Object System.Text.UTF8Encoding($false))) } catch {} }

  # 隧道 URL 变化 → 推送
  if ($active -and $turl -and $turl -ne $state.lastTunnelUrl) {
    $state.lastTunnelUrl = $turl
    Push-Msg 'DSH 访问链接已更新' '点此重新连接(在电脑上批准一次即可)。' $turl
  }
  # 局域网地址变化 → 推送(手机存的旧地址会失效，这是最常见的“打不开”原因)
  if ($lan -and $lan -ne $state.lastLanUrl) {
    $prev = $state.lastLanUrl
    $state.lastLanUrl = $lan
    if ($prev) {
      Log-Msg "lan url changed: $prev -> $lan"
      Push-Msg 'DSH 手机访问地址已变' "电脑局域网地址变了(原 $prev)。点此用新地址连接。" $lan
    } else { Log-Msg "lan url recorded: $lan" }
  }
  Write-State $state
  if ($Once) { break }
  Start-Sleep -Seconds 12
}
exit 0