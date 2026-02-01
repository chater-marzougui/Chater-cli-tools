# Verification Script
$root = "C:\custom-scripts"
$helpers = Join-Path $root "helpers"

Write-Host "1. Verifying Helpers..." -ForegroundColor Cyan
$modules = @("Utils.ps1", "NetworkUtils.ps1", "GeminiUtils.ps1", "TunnelUtils.ps1")
foreach ($m in $modules) {
    $p = Join-Path $helpers $m
    if (Test-Path $p) {
        Write-Host "  [OK] $m found" -ForegroundColor Green
        try {
            . $p
            Write-Host "  [OK] $m sourced successfully" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] $m failed to source: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  [FAIL] $m NOT found" -ForegroundColor Red
    }
}

Write-Host "`n2. Verifying Core Functions..." -ForegroundColor Cyan
if (Get-Command "Show-Header" -ErrorAction SilentlyContinue) { Write-Host "  [OK] Show-Header available" -ForegroundColor Green } else { Write-Host "  [FAIL] Show-Header missing" -ForegroundColor Red }
if (Get-Command "Get-LocalIP" -ErrorAction SilentlyContinue) { Write-Host "  [OK] Get-LocalIP available" -ForegroundColor Green } else { Write-Host "  [FAIL] Get-LocalIP missing" -ForegroundColor Red }
if (Get-Command "Invoke-GeminiAPI" -ErrorAction SilentlyContinue) { Write-Host "  [OK] Invoke-GeminiAPI available" -ForegroundColor Green } else { Write-Host "  [FAIL] Invoke-GeminiAPI missing" -ForegroundColor Red }

Write-Host "`n3. Dry Run chater.ps1..." -ForegroundColor Cyan
try {
    & "$root\chater.ps1" --small
    Write-Host "  [OK] chater.ps1 executed" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] chater.ps1 error: $_" -ForegroundColor Red
}
