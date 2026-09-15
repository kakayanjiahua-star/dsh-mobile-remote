# 一键：把「当前手机可用链接」推到你手机（隧道挂了会自动重开并验证）
# 用法：双击桌面「给手机链接.cmd」，或 powershell -File 本文件
$ErrorActionPreference = 'SilentlyContinue'
$cfgDir = 'D:\DeepSeekHarness'
$Base   = 'http://127.0.0.1:43127'

function J($p, $t = 10) { (& curl.exe -s --noproxy "*" --max-time $t ($Base + $p) | Out-String).Trim() }
function P($p, $b, $t = 150) { (& curl.exe -s --noproxy "*" --max-time $t -X POST -H "Content-Type: application/json" -d $b ($Base + $p) | Out-String).Trim() }

function Test-Dns($url) {
  if (-not $url) { return $false }
  try { $h = ([uri]$url).Host } catch { return $false }
  if (-not $h) { return $false }
  try { return [bool](Resolve-DnsName $h -Server 1.1.1.1 -DnsOnly -ErrorAction Stop | Where-Object { $_.IPAddress }) } catch { return $false }
}
function Wait-Dns($url, $seconds = 90) {
  $loops = [int]($seconds / 5)
  for ($i = 0; $i -lt $loops; $i++) {
    if (Test-Dns $url) { return $true }
    Start-Sleep -Seconds 5
  }
  return (Test-Dns $url)
}
function Send-Link($url) {
  $cfgPath = Join-Path $cfgDir 'ds-phone-notify.json'
  try { $cfg = Get-Content -Raw -Encoding UTF8 -LiteralPath $cfgPath | ConvertFrom-Json } catch { Write-Host '读取推送配置失败' -ForegroundColor Red; return }
  if (-not $cfg.barkKey) { Write-Host '还没配置 Bark key，无法推送' -ForegroundColor Red; return }
  $json = @{ device_key = $cfg.barkKey; title = 'DSH 手机链接'; body = '点开 → 重新连接（会自动批准，不用碰电脑）'; group = 'DSH'; url = $url } | ConvertTo-Json -Compress
  $tmp = Join-Path $env:TEMP ('ds-link-' + [guid]::NewGuid().ToString('N') + '.json')
  [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
  $resp = (& curl.exe -s --noproxy "*" -m 15 -X POST 'https://api.day.app/push' -H 'Content-Type: application/json; charset=utf-8' --data-binary "@$tmp" | Out-String).Trim()
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  if ($resp -match '"code":200') { Write-Host '已推送到你手机 ✅' -ForegroundColor Green } else { Write-Host ("推送返回: " + $resp) -ForegroundColor Yellow }
}

# ---- 主流程 ----
$st = J '/desktop/tunnel/status' | ConvertFrom-Json
$url = $st.url
if (-not ($st.active -and (Test-Dns $url))) {
  Write-Host '隧道当前不可用，正在重开（约 30-90 秒，请稍等）...' -ForegroundColor Yellow
  $null = P '/desktop/disconnect' '{}'
  Start-Sleep -Seconds 2
  $null = P '/desktop/tunnel/toggle' '{"enable":false}'
  Start-Sleep -Seconds 3
  $r = P '/desktop/tunnel/toggle' '{"enable":true}'
  try { $url = ($r | ConvertFrom-Json).url } catch {}
  if (-not (Test-Dns $url)) { $null = Wait-Dns $url 90 }
}

if ($url -and (Test-Dns $url)) {
  [System.IO.File]::WriteAllText((Join-Path $cfgDir 'ds-mobile-url.txt'), $url, (New-Object System.Text.UTF8Encoding($false)))
  $st2 = Get-Content -Raw -Encoding UTF8 (Join-Path $cfgDir 'ds-mobile-state.json') | ConvertFrom-Json
  $st2 | Add-Member -NotePropertyName liveTunnelUrl -NotePropertyValue $url -Force
  $st2 | Add-Member -NotePropertyName deadSince -NotePropertyValue $null -Force
  [System.IO.File]::WriteAllText((Join-Path $cfgDir 'ds-mobile-state.json'), ($st2 | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host ''
  Write-Host ('手机链接: ' + $url) -ForegroundColor Green
  Write-Host ''
  Send-Link $url
} else {
  Write-Host '隧道重开失败（可能是电脑网络/代理异常），请把这句话告诉严老板' -ForegroundColor Red
}
