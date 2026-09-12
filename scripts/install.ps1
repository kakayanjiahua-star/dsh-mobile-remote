<#
    dsh-mobile-remote installer
    ------------------------------------------------------------------
    Deploys the phone-remote runtime for DeepSeek Harness Desktop:
      1. copies runtime scripts into -InstallDir
      2. writes ds-hooks.json with absolute paths for this machine
      3. mounts the Codex hooks bridge (@deepseek-ai/dsh-hooks-codex)
         into the DSH Desktop profile patch (cordis.patch.yml)
      4. registers the tunnel/URL monitor for auto-start at logon
      5. optionally patches the gateway to accept Tailscale (100.64/10)

    Usage:
      powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1 `
                 -InstallDir "D:\dsh" [-EnableTailscale] [-SkipAutostart]

    Safe to re-run: existing config and patch entries are preserved.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = "$env:USERPROFILE\dsh-mobile",
    [switch]$EnableTailscale,
    [switch]$SkipAutostart,
    [string]$ProfilePatchPath
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Info($m) { Write-Host "[install] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[warn]    $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[error]   $m" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 1. runtime scripts
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
foreach ($f in 'ds-mobile-bridge.ps1', 'ds-phone-notify.ps1', 'ds-patch-cgnat.ps1') {
    $src = Join-Path $scriptDir $f
    if (-not (Test-Path -LiteralPath $src)) { Die "missing $src (run from a cloned repo)" }
    Copy-Item -LiteralPath $src -Destination (Join-Path $InstallDir $f) -Force
    Info "copied $f"
}

$notifyCfg = Join-Path $InstallDir 'ds-phone-notify.json'
if (-not (Test-Path -LiteralPath $notifyCfg)) {
    Copy-Item -LiteralPath (Join-Path $scriptDir 'ds-phone-notify.example.json') -Destination $notifyCfg -Force
    Info "created $notifyCfg  <-- put your Bark key here"
} else {
    Info "kept existing $notifyCfg"
}

# ---------------------------------------------------------------- 2. hooks config
$fwd = ($InstallDir -replace '\\', '/').TrimEnd('/')
$hooksRaw = Get-Content -Raw -Encoding UTF8 (Join-Path $scriptDir 'ds-hooks.json')
$hooksRaw = $hooksRaw -replace '__INSTALL_DIR__/ds-phone-notify\.ps1', "$fwd/ds-phone-notify.ps1"
$hooksPath = Join-Path $InstallDir 'ds-hooks.json'
[System.IO.File]::WriteAllText($hooksPath, $hooksRaw, (New-Object System.Text.UTF8Encoding($false)))
Info "wrote $hooksPath"

# ---------------------------------------------------------------- 3. mount hooks bridge
if (-not $ProfilePatchPath) {
    $candidates = @(
        (Join-Path $env:APPDATA 'dsh-desktop\harness\profiles\web\cordis.patch.yml'),
        (Join-Path $env:USERPROFILE '.dsh\profiles\web\cordis.patch.yml')
    )
    if ($env:DSH_HOME) { $candidates = @((Join-Path $env:DSH_HOME 'profiles\web\cordis.patch.yml')) + $candidates }
    $ProfilePatchPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $ProfilePatchPath -or -not (Test-Path -LiteralPath $ProfilePatchPath)) {
    Warn "DSH profile patch (cordis.patch.yml) not found - mount manually, see SKILL.md"
} else {
    $raw = Get-Content -Raw -Encoding UTF8 $ProfilePatchPath
    if ($raw -match 'dsh-hooks-codex') {
        Info "hooks bridge already mounted in $ProfilePatchPath"
    } else {
        Copy-Item -LiteralPath $ProfilePatchPath -Destination "$ProfilePatchPath.bak" -Force
        $block = @"
# dsh-mobile-remote: phone notifications (turn finished / agent asked a question)
- insert:
    - id: hooks-codex
      name: '@deepseek-ai/dsh-hooks-codex'
      config:
        configPath: $fwd/ds-hooks.json
"@
        $stripped = (($raw -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        if ($stripped.Trim() -eq '[]') {
            $new = $block
        } else {
            $new = $raw.TrimEnd() + "`n`n" + $block
        }
        [System.IO.File]::WriteAllText($ProfilePatchPath, $new, (New-Object System.Text.UTF8Encoding($false)))
        Info "mounted hooks bridge in $ProfilePatchPath (restart DSH Desktop to load)"
    }
}

# ---------------------------------------------------------------- 4. autostart
if (-not $SkipAutostart) {
    $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $monitorCmd = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' +
                  (Join-Path $InstallDir 'ds-mobile-bridge.ps1') + '"'
    New-ItemProperty -Path $runKey -Name 'DSHMobileBridge' -Value $monitorCmd -PropertyType String -Force | Out-Null
    Info "registered auto-start: HKCU Run key 'DSHMobileBridge'"

    # start it now
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
        '-File', (Join-Path $InstallDir 'ds-mobile-bridge.ps1')
    ) -WindowStyle Hidden | Out-Null
    Info "monitor started (log: $(Join-Path $InstallDir 'ds-mobile-bridge.log'))"
}

# ---------------------------------------------------------------- 5. optional Tailscale
if ($EnableTailscale) {
    $patcher = Join-Path $scriptDir 'ds-patch-cgnat.ps1'
    if (Test-Path -LiteralPath $patcher) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $patcher
        Info "applied Tailscale/CGNAT gateway patch (takes effect after DSH Desktop restart)"
    } else {
        Warn "ds-patch-cgnat.ps1 not found; skipping Tailscale patch"
    }
}

# ---------------------------------------------------------------- done
Write-Host ""
Write-Host "Next steps" -ForegroundColor Green
Write-Host "  1. Edit $notifyCfg and set barkKey (free Bark app on iPhone; the ~22-char string on its home screen)"
Write-Host "  2. Open DSH Desktop and press Ctrl+Shift+M, then scan the QR code with the phone camera"
Write-Host "  3. On the phone tap 'Reconnect' and approve the device on the PC"
Write-Host "  4. Restart DSH Desktop once so the hooks bridge (notifications) loads"
Write-Host ""
Write-Host "Docs: SKILL.md (agent playbook) and references/*.zh.md (human guides)" -ForegroundColor Green
