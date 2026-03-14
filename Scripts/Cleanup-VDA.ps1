<#
.SYNOPSIS
Runs the Citrix VDA Cleanup Utility, removes residual Citrix artifacts, verifies cleanup results, and reboots the device.

.DESCRIPTION
This script validates administrative access and the specified VDACleanupUtility executable path, initializes logging, runs the Citrix cleanup utility in silent mode, waits for post-cleanup processing, removes common Citrix registry keys and directories, scans for remaining Citrix uninstall entries and services, logs the verification results, and then forces a reboot.

.PARAMETER CleanupPath
Specifies the full path to VDACleanupUtility.exe.

.PARAMETER WaitSeconds
Specifies the number of seconds to wait after running the cleanup utility before continuing with additional cleanup steps. The default is 120.

.PARAMETER LogPath
Specifies the log file path used to record script activity. If the parent directory does not exist, it is created automatically. The default is %windir%\Cleanup-VDA.log.

.EXAMPLE
.\Cleanup-VDA.ps1 -CleanupPath "C:\Temp\VDACleanupUtility.exe"

Runs the Citrix VDA cleanup utility from the specified path, performs residual artifact cleanup, logs activity, verifies remaining Citrix components, and reboots the machine.

.EXAMPLE
.\Cleanup-VDA.ps1 -CleanupPath "C:\Temp\VDACleanupUtility.exe" -WaitSeconds 180 -LogPath "C:\Deploy\Cleanup-VDA\Cleanup.log"

Runs the cleanup utility, waits 180 seconds before post-cleanup actions, writes output to a custom log file, verifies cleanup status, and reboots the machine.

.NOTES
Author:     ISAIAH ROSS
Github:     https://github.com/isaiahrss
LinkedIn:   https://linkedin.com/in/isaiah-ross
Version: 1.1
Date: 2025-10-16

This script is intended for elevated execution and is suitable for use in manual remediation or automated deployment workflows.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CleanupPath,
    [int]$WaitSeconds = 120,
    [string]$LogPath = "$env:windir\Cleanup-VDA.log"
)

# Comment this out if deploying via a MDM tool that runs as SYSTEM or with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required."
    exit 1
}

if (-not (Test-Path -LiteralPath $CleanupPath -PathType Leaf)) {
    Write-Error "The specified CleanupPath '$CleanupPath' does not exist or is not a file."
    exit 1
}

if ($LogPath) {
    try {
        $logDir = Split-Path -Path $LogPath -Parent
        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $LogPath)) {
            New-Item -Path $LogPath -ItemType File -Force | Out-Null
        }
    } catch {
        Write-Host "Failed to initialize log file: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ========== Logging ==========
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Level = "INFO"
    )
    $ts   = (Get-Date).ToString("s")
    $line = "[$ts] [$Level] $Message"
    Write-Host $line
    if ($LogPath) {
    try {
        $logDir = Split-Path -Path $LogPath -Parent
        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $LogPath -Value $line -ErrorAction Stop
    } catch {
        Write-Host "Failed to write log: $($_.Exception.Message)" -ForegroundColor Red
    }
}
}

# ========== Helpers ==========
function Remove-RegistryKey {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        try { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop; Write-Log "Removed registry key: $Path" "SUCCESS" }
        catch { Write-Log "Failed to remove registry key: $Path $($_.Exception.Message)" "ERROR" }
    } else {
        Write-Log "Registry key not present: $Path"
    }
}

function Remove-DirectoryPath {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        # retry a couple times for transient locks
        for ($i=1; $i -le 3; $i++) {
            try { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop; Write-Log "Removed directory: $Path" "SUCCESS"; break }
            catch {
                if ($i -lt 3) { Write-Log "Retry $i removing: $Path $($_.Exception.Message)" "WARN"; Start-Sleep -Seconds 3 }
                else { Write-Log "Failed to remove directory: $Path $($_.Exception.Message)" "ERROR" }
            }
        }
    } else {
        Write-Log "Directory not present: $Path"
    }
}

# ========== 1) Run Citrix Cleanup Utility ==========
Write-Log "Starting Citrix VDA cleanup"
Write-Log "Executing: `"$CleanupPath`" /silent /noreboot"
try {
    $proc = Start-Process -FilePath $CleanupPath -ArgumentList '/silent','/noreboot' -Wait -PassThru -WindowStyle Hidden
    Write-Log "VDACleanupUtility exit code: $($proc.ExitCode)"
} catch {
    Write-Log "Failed to run VDACleanupUtility  $($_.Exception.Message)" "ERROR"
}

# ========== 2) Wait for post-ops ==========
Write-Log "Waiting $WaitSeconds seconds for post-cleanup operations..."
Start-Sleep -Seconds $WaitSeconds

# ========== 3) Remove core Citrix registry/service keys ==========
$CitrixCoreKeys = @(
  "HKLM:\SOFTWARE\Citrix",
  "HKLM:\SOFTWARE\WOW6432Node\Citrix",
  "HKLM:\SYSTEM\CurrentControlSet\Services\PortICAService",
  "HKLM:\SYSTEM\CurrentControlSet\Services\BrokerAgent",
  "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce\!XenDesktopSetup"
)
$CitrixCoreKeys | ForEach-Object { Remove-RegistryKey -Path $_ }

# ========== 4) Remove Citrix entries under Uninstall (x64 & x86) ==========
$UninstallHives = @(
 "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
 "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($h in $UninstallHives) {
    Write-Log "Scanning uninstall hive: $h"
    Get-ChildItem $h -ErrorAction SilentlyContinue | ForEach-Object {
        try { $p = Get-ItemProperty $_.PSPath -ErrorAction Stop } catch { return }
        if ($p.DisplayName -and ($p.DisplayName -match "Citrix")) {
            Write-Log "Removing uninstall key: $($p.DisplayName) [$($_.PSChildName)]"
            Remove-RegistryKey -Path $_.PSPath
        }
    }
}

# ========== 5) Delete Citrix directories ==========
$CitrixDirs = @(
  "C:\Program Files\Citrix",
  "C:\Program Files (x86)\Citrix",
  "C:\ProgramData\Citrix",
  "C:\Windows\System32\LogFiles\Citrix"
)
$CitrixDirs | ForEach-Object { Remove-DirectoryPath -Path $_ }

# ========== 6) Final verification scan ==========
Write-Log "Starting final verification scan..."

# Services (should be gone or disabled)
$svcCitrix = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Citrix|BrokerAgent|PortICA" -or $_.DisplayName -match "Citrix" }
if ($svcCitrix) {
    Write-Log "Services still present:" "WARN"
    $svcCitrix | ForEach-Object { Write-Log (" - {0} (Status={1}, StartType={2})" -f $_.Name, $_.Status, $_.StartType) }
} else { Write-Log "No Citrix-related services detected." "SUCCESS" }

# Files/directories
$dirsRemaining = $CitrixDirs | Where-Object { Test-Path $_ }
if ($dirsRemaining) {
    Write-Log "Directories still present:" "WARN"
    $dirsRemaining | ForEach-Object { Write-Log (" - {0}" -f $_) }
} else { Write-Log "No Citrix directories remain." "SUCCESS" }

# Registry — core keys
$coreRemain = $CitrixCoreKeys | Where-Object { Test-Path $_ }
if ($coreRemain) {
    Write-Log "Registry core keys still present:" "WARN"
    $coreRemain | ForEach-Object { Write-Log (" - {0}" -f $_) }
} else { Write-Log "No Citrix core registry keys remain." "SUCCESS" }

# Registry — uninstall keys
$uninstRemain = foreach ($h in $UninstallHives) {
    Get-ChildItem $h -ErrorAction SilentlyContinue | ForEach-Object {
        try { Get-ItemProperty $_.PSPath -ErrorAction Stop } catch { return }
    } | Where-Object { $_.DisplayName -like "*Citrix*" }
}
if ($uninstRemain) {
    Write-Log "Uninstall keys still present:" "WARN"
    $uninstRemain | ForEach-Object { Write-Log (" - {0} [{1}]" -f $_.DisplayName, $_.PSChildName) }
} else { Write-Log "No Citrix uninstall registry entries remain." "SUCCESS" }

# Summary
if (-not $svcCitrix -and -not $dirsRemaining -and -not $coreRemain -and -not $uninstRemain) {
    Write-Log "FINAL VERIFICATION: Citrix appears fully removed." "SUCCESS"
} else {
    Write-Log "FINAL VERIFICATION: Residual artifacts remain (see warnings above)." "WARN"
}

# ========== 7) Reboot ==========
Write-Log "Rebooting now..."
Restart-Computer -Force
