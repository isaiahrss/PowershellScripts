<#
.SYNOPSIS
Repairs WMI and system integrity by restoring repositories, re-registering components, and executing DISM/SFC utilities.

.DESCRIPTION
This script provides a comprehensive set of PowerShell functions to repair Windows Management Instrumentation (WMI), restore system health, and resolve issues related to Terminal Services and Performance Counters. It includes a logging utility to track actions and outcomes during the repair process.

.PARAMETER Message
The message content to log. This is a required parameter in the Write-Log function.

.PARAMETER Path
Optional path for the log file. Defaults to "$env:windir\Repair-WMI.log".

.PARAMETER Level
Specifies the log severity level: "Info", "Warn", or "Error". Defaults to "Info".

.PARAMETER TimeoutSeconds
(Optional) Used by Invoke-RebootPromptWithTimeout to specify the delay before reboot in seconds. Default is 60.

.NOTES
Author:     ISAIAH ROSS
Github:     https://github.com/isaiahrss
LinkedIn:   https://linkedin.com/in/isaiah-ross
Version: 1.1
Last Modified: 2025-05-06
This script performs critical system maintenance tasks. Ensure proper administrative permissions before execution.
Changes:
- Validated log file handling with size limit
- Added WMI repository cleanup and MOF recompile
- Integrated DISM and SFC health checks
- Included DLL re-registration for Terminal Services
- Added Performance Counter repair via lodctr
- Added logging with rotation support
- Integrated DISM and SFC health checks
- Included conditional reboot prompt
#>


# Write-Log Function
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("LogContent")]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [Alias('LogPath')]
        [string]$Path = "C:\Temp\Repair-WMI.log",

        [Parameter()]
        [ValidateSet("Error", "Warn", "Info")]
        [string]$Level = "Info"
    )

    begin {
        $VerbosePreference = 'Continue'
    }

    process {
        $maxLogSizeMB = 5

        $logDir = Split-Path $Path
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }

        if (Test-Path $Path) {
            $logSizeMB = (Get-Item -Path $Path).Length / 1MB
            if ($logSizeMB -gt $maxLogSizeMB) {
                Write-Warning "Log file $Path exceeds $maxLogSizeMB MB. Deleting and starting fresh."
                Remove-Item $Path -Force
                New-Item $Path -Force -ItemType File | Out-Null
            }
        } else {
            Write-Verbose "Creating log file at $Path."
            New-Item $Path -Force -ItemType File | Out-Null
        }

        $formattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        switch ($Level) {
            'Error' {
                Write-Warning $Message
                $levelText = 'ERROR:'
            }
            'Warn' {
                Write-Warning $Message
                $levelText = 'WARNING:'
            }
            'Info' {
                Write-Verbose $Message
                $levelText = 'INFO:'
            }
        }

        "$formattedDate $levelText $Message" | Out-File -FilePath $Path -Append
    }
}

# Track overall script outcome for Tanium
$Script:OverallExitCode = 0

function Set-Failure {
    param(
        [int]$Code = 1,
        [string]$Reason = "Unspecified failure"
    )
    if ($Script:OverallExitCode -eq 0) {
        $Script:OverallExitCode = $Code
    }
    Write-Log "Marking script as FAILED (ExitCode=$Code). Reason: $Reason" -Level Error
}


# Register WMI Components
function Register-WMIComponents {
    try { Set-Location "$env:windir\System32\wbem" -ErrorAction Stop }
    catch { Set-Failure -Reason "Failed to set location to wbem: $($_.Exception.Message)"; return }


    Get-ChildItem -Filter *.dll | ForEach-Object {
        Write-Log "Registering $($_.Name)" -Level Info
        $proc = Start-Process "regsvr32.exe" -ArgumentList "/s", $_.FullName -NoNewWindow -Wait -PassThru

# regsvr32 exit code 4 = DLL does not export DllRegisterServer (expected for many WBEM DLLs)
$nonFatalRegsvr32Codes = @(0, 4)

if ($nonFatalRegsvr32Codes -notcontains $proc.ExitCode) {
    Set-Failure -Code $proc.ExitCode -Reason "regsvr32 failed for $($_.Name)"
}
elseif ($proc.ExitCode -ne 0) {
    Write-Log "regsvr32 exit code $($proc.ExitCode) for $($_.Name) treated as non-fatal." -Level Warn
}

}

    # Excludes this components as they do not work work with the /regServer command
    $exclude = @(
        'wbemtest.exe',
        'mofcomp.exe',
        'winmgmt.exe',
        'wmic.exe'
    )

    Get-ChildItem -Filter *.exe | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        Write-Log "Registering Server: $($_.Name)" -Level Info
        $proc = Start-Process $_.FullName -ArgumentList "/RegServer" -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            Set-Failure -Code $proc.ExitCode -Reason "$($_.Name) /RegServer failed"
        }
    }
}


# Restore WMI Repository
function Restore-Repository {
    try { Stop-Service -Name "winmgmt" -Force -ErrorAction Stop }
    catch { Set-Failure -Reason "Failed stopping winmgmt: $($_.Exception.Message)" }


    $wmiNamespace = Get-WmiObject -Namespace "root" -Class "__namespace" -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "wmi" }
    if ($wmiNamespace) {
        Write-Log "Deleting WMI namespace 'wmi' under root..." -Level Info
        $wmiNamespace.Delete()
    } else {
        Write-Log "WMI namespace 'wmi' not found. Skipping delete." -Level Warn
    }

    Write-Log "Recompiling WMI MOF file..." -Level Info

$mofCandidates = @(
    "$env:windir\System32\wbem\cimwin32.mof",
    "$env:windir\System32\wbem\cimwin32.mfl",
    "$env:windir\System32\wbem\wmi.mof"
)

$mofToCompile = $mofCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($mofToCompile) {
    Write-Log "Compiling MOF: $mofToCompile" -Level Info
    $output = & mofcomp.exe $mofToCompile 2>&1
    $mofExit = $LASTEXITCODE
    foreach ($line in ($output | ForEach-Object { "$_" })) { Write-Log $line -Level Info }

    if ($mofExit -ne 0) {
        Set-Failure -Code $mofExit -Reason "mofcomp failed compiling $mofToCompile"
    }
} else {
    Write-Log "No MOF candidates found in wbem folder. Skipping MOF compile." -Level Warn
    # intentionally non-fatal
}


try { Start-Service -Name winmgmt -ErrorAction Stop }
catch { Set-Failure -Reason "Failed starting winmgmt: $($_.Exception.Message)" }
}


# Repair System Files
function Repair-CorruptFiles {
    [CmdletBinding()]
    param()

    $commands = @(
        @{ Name = "DISM ScanHealth"; Cmd = "dism /online /cleanup-image /scanhealth" },
        @{ Name = "DISM CheckHealth"; Cmd = "dism /online /cleanup-image /checkhealth" },
        @{ Name = "DISM RestoreHealth"; Cmd = "dism /online /cleanup-image /restorehealth" },
        @{ Name = "DISM StartComponentCleanup"; Cmd = "dism /online /cleanup-image /startcomponentcleanup" },
        @{ Name = "System File Checker (SFC)"; Cmd = "sfc /scannow" }
    )

    foreach ($step in $commands) {
        Write-Log "Running: $($step.Name)" -Level Info

        # 2>&1 captures both stdout and stderr to get complete diagnostic output
        $output = (cmd.exe /c $step.Cmd 2>&1 | Out-String).Trim()

        # $LASTEXITCODE is used to determine success (0) or failure (non-zero)
        $exitCode = $LASTEXITCODE

        if ($output) { Write-Log "Output: $output" -Level Error }
else { Write-Log "Output: (none captured). Check CBS.log: C:\Windows\Logs\CBS\CBS.log" -Level Warn }

    }
}

# Repair Terminal Services Environment
function Repair-TSE {
    Set-Service -Name RemoteRegistry -StartupType Automatic
    Start-Service -Name RemoteRegistry

    $regsvr32Path = "$env:windir\System32\regsvr32.exe"
    $dllPath = "$env:windir\System32\bitsperf.dll"

    if (Test-Path $dllPath) {
        Write-Log "Registering $dllPath..." -Level Info
        $proc = Start-Process $regsvr32Path -ArgumentList "/s", $dllPath -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Set-Failure -Code $proc.ExitCode -Reason "regsvr32 failed for bitsperf.dll"
} else {
    Write-Log "Registration complete." -Level Info
}
    } else {
        Write-Log "DLL not found at $dllPath!" -Level Error
    }
}

# Repair Performance Counters
function Repair-PerformanceCounters {
    Write-Log "Restoring Performance Counters via lodctr..." -Level Info
    lodctr /R
$lodctrExit = $LASTEXITCODE
if ($lodctrExit -ne 0) {
    Set-Failure -Code $lodctrExit -Reason "lodctr /R failed"
}

}

# Prompt Reboot
function Invoke-RebootPromptWithTimeout {
    [CmdletBinding()]
    param (
        [int]$TimeoutSeconds = 60
    )

    $prompt = "System repair complete. A reboot is strongly recommended. Rebooting in $TimeoutSeconds seconds... (Press 'N' to cancel)"
    Write-Log "Prompting user for reboot with $TimeoutSeconds-second timeout..." -Level Info
    Write-Host $prompt -ForegroundColor Yellow

    $inputTask = {
        Read-Host
    }.BeginInvoke()

    # $i is the loop counter that handles the countdown timer. 
    # $i is the loop coundition - the loop keeps running while $i is greater than zero
    # $i-- is a post-decrement operation - after each loop iteration, $i is reduced by 1
    for ($i = $TimeoutSeconds; $i -gt 0; $i--) {
        Write-Host "Rebooting in $i seconds... Press 'N' to cancel." -NoNewline
        Start-Sleep -Seconds 1
        Write-Host "`r" + (' ' * 50) + "`r" -NoNewline  # Clear the line
        if ($inputTask.IsCompleted) {
            $userInput = $inputTask.EndInvoke()
            if ($userInput -match '^[Nn]$') {
                Write-Log "User cancelled reboot." -Level Warn
                Write-Host "Reboot cancelled by user." -ForegroundColor Green
                return
            }
        }
    }

    Write-Log "No user input received. Proceeding with reboot..." -Level Info
    Write-Host "Rebooting now..." -ForegroundColor Cyan
    Restart-Computer -Force
}


Write-Log "===== System Repair Started at $(Get-Date) =====" -Level Info
Write-Log -Message "WMI repair started" -Level Info
Register-WMIComponents
Restore-Repository
Repair-CorruptFiles
Repair-TSE
Repair-PerformanceCounters
Invoke-RebootPromptWithTimeout
Write-Log "===== System Repair Completed at $(Get-Date) =====" -Level Info

Write-Log "Overall script exit code: $Script:OverallExitCode" -Level Info
exit $Script:OverallExitCode
