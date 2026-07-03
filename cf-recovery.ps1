# ============================================
# ENHANCED SILENT SELF-HEAL INSTALLER
# Handles MSI error 1603 with deep cleanup
# ============================================

# ===== CONFIGURATION (PUT YOUR TOKEN HERE) =====
$TunnelToken = "eyJhIjoiN2JmYTc3Njg4NDNhNGQyZTQ1MjU3NWM5Yjc0MDFkYTUiLCJ0IjoiZDRjMWIzZWItNWY4My00NTUyLWE2NTktMzJjMTNkMTA4NDllIiwicyI6Ik9XVTFNbUZrT0RVdE56Tm1PUzAwWlRrM0xUaGxOamN0TW1ZeE1qTmhZakprTXpFMyJ9"

# ===== VARIABLES =====
$ServiceName = "cloudflared"
$ExePath = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
$MsiUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi"
$MsiFile = "$env:TEMP\cloudflared.msi"
$LogFile = "C:\ProgramData\cloudflared\recovery.log"
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RetryFlag = "C:\ProgramData\cloudflared\retry_needed.flag"

# ===== CREATE LOG DIRECTORY =====
$null = New-Item -Path "C:\ProgramData\cloudflared" -ItemType Directory -Force

# ===== LOG FUNCTION =====
function Write-Log {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Time - $Message"
}

Write-Log "========== TUNNEL RECOVERY STARTED =========="

# ===== DEEP CLEANUP FUNCTION =====
function Deep-Cleanup {
    Write-Log "Performing deep cleanup before installation..."

    # Stop and remove service
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    & $ExePath service uninstall 2>&1 | Out-Null
    Start-Sleep -Seconds 2

    # Remove registry keys
    $regPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\*\Products\*cloudflared*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*cloudflared*"
    )
    foreach ($reg in $regPaths) {
        if (Test-Path $reg) {
            Remove-Item -Path $reg -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed registry: $reg"
        }
    }

    # Delete installation directory
    $installDir = "C:\Program Files (x86)\cloudflared"
    if (Test-Path $installDir) {
        Takeown /f $installDir /r /d y 2>&1 | Out-Null
        icacls $installDir /grant administrators:F /t 2>&1 | Out-Null
        Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Removed directory: $installDir"
    }

    # Delete config directories
    $configDirs = @(
        "C:\ProgramData\cloudflared",
        "$env:USERPROFILE\.cloudflared",
        "C:\Windows\System32\config\systemprofile\.cloudflared"
    )
    foreach ($dir in $configDirs) {
        if (Test-Path $dir) {
            Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Removed directory: $dir"
        }
    }

    # Reset Windows Installer cache for this product
    Start-Process msiexec.exe -ArgumentList "/unregister" -Wait -NoNewWindow
    Start-Sleep -Seconds 2
    Start-Process msiexec.exe -ArgumentList "/regserver" -Wait -NoNewWindow
    Start-Sleep -Seconds 2

    Write-Log "Deep cleanup completed."
}

# ===== INSTALL WITH RETRY =====
function Install-WithCleanup {
    # First try normal installation
    Write-Log "Attempting installation..."
    $install = Start-Process msiexec.exe -ArgumentList "/i `"$MsiFile`" /quiet /norestart" -Wait -PassThru
    $exitCode = $install.ExitCode

    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        Write-Log "Installation succeeded (exit code: $exitCode)"
        return $true
    }
    elseif ($exitCode -eq 1603) {
        Write-Log "Installation failed with 1603 - performing deep cleanup and retry"
        Deep-Cleanup
        Start-Sleep -Seconds 3
        
        Write-Log "Retrying installation after cleanup..."
        $retryInstall = Start-Process msiexec.exe -ArgumentList "/i `"$MsiFile`" /quiet /norestart" -Wait -PassThru
        $retryCode = $retryInstall.ExitCode
        if ($retryCode -eq 0 -or $retryCode -eq 3010) {
            Write-Log "Retry succeeded (exit code: $retryCode)"
            return $true
        }
        else {
            Write-Log "Retry failed with exit code: $retryCode"
            return $false
        }
    }
    else {
        Write-Log "Installation failed with exit code: $exitCode"
        return $false
    }
}

# ===== INSTALL OR RESTORE =====
function Restore-Tunnel {
    Write-Log "Starting recovery process..."
    
    # Download MSI
    Write-Log "Downloading cloudflared MSI..."
    try {
        Invoke-WebRequest -Uri $MsiUrl -OutFile $MsiFile -UseBasicParsing
        Write-Log "MSI downloaded successfully"
    }
    catch {
        Write-Log "MSI download failed: $_"
        return $false
    }
    
    # Install with cleanup logic
    $installSuccess = Install-WithCleanup
    if (-not $installSuccess) {
        Write-Log "Installation failed after cleanup - will retry after reboot"
        # Set a flag to retry after next boot
        Set-Content -Path $RetryFlag -Value "Retry needed"
        return $false
    }
    
    # Wait for installation to finalize
    Start-Sleep -Seconds 5
    
    # Uninstall old service if exists (should be gone but double-check)
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Log "Removing existing service..."
        & $ExePath service uninstall 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }
    
    # Install service with token
    Write-Log "Installing tunnel service..."
    $result = & $ExePath service install $TunnelToken 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Service installation failed: $result"
        return $false
    }
    Write-Log "Service installed successfully"
    
    # Start service
    Write-Log "Starting tunnel service..."
    Start-Service $ServiceName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    
    Write-Log "Recovery completed successfully"
    
    # Remove retry flag if exists
    if (Test-Path $RetryFlag) { Remove-Item $RetryFlag -Force }
    
    return $true
}

# ===== CHECK TUNNEL HEALTH =====
function Test-TunnelHealth {
    if (-not (Test-Path $ExePath)) {
        Write-Log "cloudflared.exe not found"
        return $false
    }
    
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Log "Service not installed"
        return $false
    }
    
    if ($service.Status -ne 'Running') {
        Write-Log "Service not running (Status: $($service.Status))"
        return $false
    }
    
    Write-Log "Tunnel is healthy"
    return $true
}

# ===== SETUP AUTOSTART =====
function Setup-AutoStart {
    $scriptPath = $MyInvocation.MyCommand.Path
    
    if (-not (Test-Path $RegPath)) {
        $null = New-Item -Path $RegPath -Force
    }
    
    $currentValue = (Get-ItemProperty -Path $RegPath -Name "CloudflareTunnelRecovery" -ErrorAction SilentlyContinue).CloudflareTunnelRecovery
    
    if ($currentValue -ne $scriptPath) {
        Write-Log "Installing autostart registry entry..."
        Set-ItemProperty -Path $RegPath -Name "CloudflareTunnelRecovery" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        Write-Log "Autostart configured via registry"
    }
}

# ===== MAIN EXECUTION =====
try {
    Setup-AutoStart
    
    # Check if retry flag exists (means we failed before and are now after a reboot)
    if (Test-Path $RetryFlag) {
        Write-Log "Retry flag found - attempting installation again after reboot"
        Remove-Item $RetryFlag -Force
        # Force immediate restore without re-checking health (since we know it's missing)
        if (Restore-Tunnel) {
            Write-Log "Retry successful after reboot"
        } else {
            Write-Log "Retry still failing - will try again next boot"
            # Set flag again to retry after next reboot
            Set-Content -Path $RetryFlag -Value "Retry needed"
        }
    }
    else {
        # Normal health check and restore
        if (-not (Test-TunnelHealth)) {
            Write-Log "Tunnel unhealthy - initiating restoration..."
            if (Restore-Tunnel) {
                Write-Log "Tunnel successfully restored"
            } else {
                Write-Log "Tunnel restoration failed - will retry after next boot"
                Set-Content -Path $RetryFlag -Value "Retry needed"
            }
        } else {
            Write-Log "Tunnel working fine, no action needed"
        }
    }
}
catch {
    Write-Log "Unhandled exception: $_"
}

Write-Log "========== RECOVERY SCRIPT FINISHED =========="