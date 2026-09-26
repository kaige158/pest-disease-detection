# Reset admin password (localhost only)
#
# WHY: the platform has no SMS/email channel yet, so a forgotten admin password
#      would otherwise be unrecoverable. This script calls a backend endpoint that
#      ONLY accepts requests from 127.0.0.1 and requires an ops token.
#
# USAGE
#   powershell -ExecutionPolicy Bypass -File scripts\reset_admin_password.ps1 -Password NewPass123
#   powershell -ExecutionPolicy Bypass -File scripts\reset_admin_password.ps1 -Password NewPass123 -Account admin -Port 8080
#
# TOKEN SOURCE (first match wins)
#   1. $env:OPS_TOKEN
#   2. OPS_TOKEN=... inside spring-backend\.env or .env
#   3. The demo profile default: local-dev-reset-token
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads BOM-less files as
#       ANSI (GBK on Chinese Windows) and non-ASCII text breaks parsing.

param(
    [Parameter(Mandatory = $true)][string]$Password,
    [string]$Account = "admin",
    [int]$Port = 8080,
    [string]$BaseUrl = "",
    [string]$Token = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Get-OpsToken {
    param([string]$Explicit, [string]$Root)
    if ($Explicit) { return $Explicit }
    if ($env:OPS_TOKEN) { return $env:OPS_TOKEN }
    foreach ($f in @((Join-Path $Root "spring-backend\.env"), (Join-Path $Root ".env"))) {
        if (Test-Path $f) {
            $m = Select-String -Path $f -Pattern '^\s*OPS_TOKEN\s*=\s*(.+)$' -ErrorAction SilentlyContinue |
                 Select-Object -First 1
            if ($m) { return $m.Matches[0].Groups[1].Value.Trim() }
        }
    }
    # Demo profile ships with this fixed token so password recovery works out of the box
    return "local-dev-reset-token"
}

$opsToken = Get-OpsToken -Explicit $Token -Root $repoRoot
if (-not $BaseUrl) { $BaseUrl = "http://127.0.0.1:$Port" }
$uri = "$BaseUrl/api/v1/ops/reset-password"

if ($Password.Length -lt 6) {
    Write-Host "ERROR: password must be at least 6 characters." -ForegroundColor Red
    exit 1
}

$payload = @{ account = $Account; newPassword = $Password; token = $opsToken } | ConvertTo-Json -Compress
$bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

Write-Host "Resetting password for [$Account] via $uri" -ForegroundColor Cyan

try {
    $resp = Invoke-RestMethod -Uri $uri -Method Post `
        -ContentType "application/json; charset=utf-8" `
        -Body $bytes -TimeoutSec 20
} catch {
    Write-Host "ERROR: request failed - $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check: (1) backend is running on port $Port" -ForegroundColor Yellow
    Write-Host "       (2) app.ops-token matches the token used here" -ForegroundColor Yellow
    exit 1
}

if ($resp.code -eq 200) {
    Write-Host "OK: password has been reset." -ForegroundColor Green
    Write-Host "    account = $($resp.data.account)   role = $($resp.data.role)" -ForegroundColor Green
    Write-Host "    Log in at $BaseUrl/admin/login and change it to a strong one." -ForegroundColor Yellow
    exit 0
}

Write-Host "FAILED: $($resp.message)" -ForegroundColor Red
Write-Host "Hint: 403 means the ops endpoint is disabled (app.ops-token empty) or the token is wrong." -ForegroundColor Yellow
exit 1
