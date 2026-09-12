# 重打「网关放行 Tailscale / CGNAT(100.64.0.0/10)」补丁。
# 用途：DSH Desktop 升级会覆盖 out/main/index.js，运行本脚本即可重新应用。
# 用法：powershell -File ds-patch-cgnat.ps1 [-MainBundle "<out\main\index.js 的完整路径>"]
param([string]$MainBundle)

$ErrorActionPreference = 'Stop'

if (-not $MainBundle) {
  $MainBundle = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\DSH Desktop\resources\app\out\main\index.js'),
    (Join-Path $env:ProgramFiles   'DSH Desktop\resources\app\out\main\index.js'),
    (Join-Path $env:ProgramFiles   'DeepSeek Harness\resources\app\out\main\index.js'),
    'D:\dsh\DSH Desktop\resources\app\out\main\index.js'
  ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $MainBundle) {
  Write-Error 'main bundle not found - pass -MainBundle "<...>\DSH Desktop\resources\app\out\main\index.js"'
  exit 1
}
$p = $MainBundle

$old = "    if (!isPrivateAddress(transportAddress)) return this.text(response, 403, `"Private network only.`");"
$new = "    const cgnatOk = /^100\.(6[4-9]|[7-9]\d|1[0-2][0-7])\./.test(transportAddress);`n    if (!(isPrivateAddress(transportAddress) || cgnatOk)) return this.text(response, 403, `"Private network only.`");"

if (-not (Test-Path -LiteralPath $p)) { Write-Error "main bundle not found: $p"; exit 1 }
$raw = [System.IO.File]::ReadAllText($p)
if ($raw.Contains('cgnatOk')) { Write-Output 'already patched - nothing to do'; exit 0 }

[System.IO.File]::Copy($p, ($p + '.bak-cgnat'), $true)
$count = ([regex]::Matches($raw, [regex]::Escape($old))).Count
if ($count -ne 1) { Write-Error "unexpected match count ($count) - patch aborted"; exit 1 }

$raw = $raw.Replace($old, $new)
[System.IO.File]::WriteAllText($p, $raw, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'patched OK (restart DSH Desktop to apply)'
exit 0