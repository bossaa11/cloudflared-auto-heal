# ============================================
# UNINSTALL SCRIPT FOR CLOUDFLARED AUTO-HEAL
# Removes all stealth files, registry entries, and services
# ============================================

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

Write-Host "Starting uninstallation of Cloudflared Auto-Heal system..." -ForegroundColor Yellow

# ===== Stop and uninstall cloudflared service =====
$serviceName = "cloudflared"
$exePath = "C:\Program Files (x86)\cloudflared\cloudflared.exe"

if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    Write-Host "Stopping cloudflared service..." -ForegroundColor Cyan
    Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

if (Test-Path $exePath) {
    Write-Host "Uninstalling cloudflared service..." -ForegroundColor Cyan
    & $exePath service uninstall 2>&1 | Out-Null
    Start-Sleep -Seconds 2
}

# ===== Delete registry autostart entry =====
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$regName = "CloudflareTunnelRecovery"

if (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue) {
    Write-Host "Removing registry autostart entry..." -ForegroundColor Cyan
    Remove-ItemProperty -Path $regPath -Name $regName -Force
}

# ===== Delete all installed files and directories =====
$filesToDelete = @(
    "C:\Windows\System32\spool\drivers\color\cf-recovery.ps1",
    "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Windows\INetCache\cf-recovery.backup.ps1",
    "C:\Windows\System32\GroupPolicy\Machine\Scripts\cf-bootstrap.ps1"
)

$dirsToDelete = @(
    "C:\Windows\System32\spool\drivers\color\logs"
)

foreach ($file in $filesToDelete) {
    if (Test-Path $file) {
        Write-Host "Deleting file: $file" -ForegroundColor Cyan
        Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
    }
}

foreach ($dir in $dirsToDelete) {
    if (Test-Path $dir) {
        Write-Host "Deleting directory: $dir" -ForegroundColor Cyan
        Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ===== (Optional) Delete cloudflared installation folder if empty =====
$installDir = "C:\Program Files (x86)\cloudflared"
if (Test-Path $installDir) {
    $items = Get-ChildItem -Path $installDir -Force -ErrorAction SilentlyContinue
    if (-not $items) {
        Write-Host "Deleting empty installation directory: $installDir" -ForegroundColor Cyan
        Remove-Item -Path $installDir -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "Installation directory not empty. Skipping: $installDir" -ForegroundColor Yellow
    }
}

# ===== Clean up any temporary files (optional) =====
$tempFiles = @(
    "$env:TEMP\cloudflared.msi",
    "$env:TEMP\cf-recovery.ps1",
    "$env:TEMP\Office-Network.ps1"
)

foreach ($temp in $tempFiles) {
    if (Test-Path $temp) {
        Write-Host "Deleting temporary file: $temp" -ForegroundColor Cyan
        Remove-Item -Path $temp -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Uninstallation complete! All components have been removed." -ForegroundColor Green
Write-Host "Please restart your computer to finalize the cleanup." -ForegroundColor Yellow
