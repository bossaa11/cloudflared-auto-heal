# ============================================
# CLOUDFLARED AUTO-HEAL COMPLETE REMOVAL
# Removes all files, services, registry entries
# ============================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CLOUDFLARED REMOVAL SCRIPT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run as Administrator." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host ""
Write-Host "[1/5] Stopping cloudflared service..." -ForegroundColor Yellow
Stop-Service -Name "cloudflared" -Force -ErrorAction SilentlyContinue
Write-Host "  -> Service stopped (if running)." -ForegroundColor Green

Write-Host ""
Write-Host "[2/5] Uninstalling cloudflared service..." -ForegroundColor Yellow
$exePath = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
if (Test-Path $exePath) {
    & $exePath service uninstall 2>&1 | Out-Null
    Write-Host "  -> Service uninstalled." -ForegroundColor Green
} else {
    Write-Host "  -> Executable not found, skipping." -ForegroundColor Gray
}

Write-Host ""
Write-Host "[3/5] Deleting installation directories..." -ForegroundColor Yellow
$dirs = @(
    "C:\Program Files (x86)\cloudflared",
    "C:\ProgramData\cloudflared",
    "$env:USERPROFILE\.cloudflared",
    "C:\Windows\System32\config\systemprofile\.cloudflared"
)
foreach ($dir in $dirs) {
    if (Test-Path $dir) {
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  -> Deleted: $dir" -ForegroundColor Green
    } else {
        Write-Host "  -> Not found: $dir" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "[4/5] Removing registry autostart entry..." -ForegroundColor Yellow
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$regName = "CloudflareTunnelRecovery"
try {
    Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    Write-Host "  -> Registry entry removed." -ForegroundColor Green
} catch {
    Write-Host "  -> Registry entry not found." -ForegroundColor Gray
}

Write-Host ""
Write-Host "[5/5] Cleaning up temporary files..." -ForegroundColor Yellow
$tempFiles = @(
    "$env:TEMP\cloudflared.msi",
    "$env:TEMP\cf-recovery.ps1",
    "$env:TEMP\Office-Network.ps1",
    "$env:TEMP\remove-cloudflared.ps1"
)
foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
        Write-Host "  -> Deleted: $file" -ForegroundColor Green
    }
}
Write-Host "  -> Temporary files cleaned." -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  REMOVAL COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"
