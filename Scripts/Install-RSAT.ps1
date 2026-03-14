<#
.SYNOPSIS
Installs or uninstalls RSAT features on supported Windows systems.

.DESCRIPTION
This script checks for administrative privileges, verifies the Windows build meets the minimum requirement, detects pending reboot conditions, and then installs or removes RSAT Windows capabilities based on the selected switch parameter. It also writes actions, warnings, and errors to a log file.

.PARAMETER All
Installs all available RSAT features that are not currently installed.

.PARAMETER Basic
Installs a basic RSAT feature set, including Active Directory, DHCP, DNS, Group Policy, and Server Manager tools.

.PARAMETER Uninstall_Basic
Removes the basic RSAT feature set if currently installed.

.PARAMETER Uninstall_All
Removes all installed RSAT features except components excluded by the script logic.

.EXAMPLE
.\Install-RSAT.ps1 -All

Installs all available RSAT features from the configured Features on Demand source.

.EXAMPLE
.\Install-RSAT.ps1 -Basic

Installs the basic RSAT administration tools defined in the script.

.EXAMPLE
.\Install-RSAT.ps1 -Uninstall_Basic

Removes the basic RSAT administration tools defined in the script.

.EXAMPLE
.\Install-RSAT.ps1 -Uninstall_All

Removes all RSAT features targeted by the script.

.NOTES
Author: Isaiah Ross
Requires: Administrative privileges, Windows 10/11 build 17763 or later, and access to the local Features on Demand source at C:\Source\RSAT_CAB_Files
Log File: %windir%\Install-RSAT.log

Recent Changes:
- Added mutually exclusive parameter sets for install and uninstall actions.
- Improved validation for missing action parameters.
- Cleaned up log file creation logic and null-comparison style.
- Refined uninstall filtering for RSAT capability removal.

#>

[CmdletBinding(DefaultParameterSetName='None')]
param(
    [Parameter(ParameterSetName='InstallAll')]
    [switch]$All,

    [Parameter(ParameterSetName='InstallBasic')]
    [switch]$Basic,

    [Parameter(ParameterSetName='UninstallBasic')]
    [switch]$Uninstall_Basic,

    [Parameter(ParameterSetName='UninstallAll')]
    [switch]$Uninstall_All
)

$global:ScriptFailed = $false

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Admin privileges required"
    exit 1
}

$Build1809 = 17763
$windowsBuild = [int](Get-CimInstance -Class Win32_OperatingSystem).BuildNumber

if (-not ($All -or $Basic -or $Uninstall_Basic -or $Uninstall_All)) {
    Write-Log -Message "No action parameter specified. Use -All, -Basic, -Uninstall_Basic, or -Uninstall_All." -Level Error
    exit 1
}

# Create Write-Log function
function Write-Log() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$message,
        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$path = "$env:windir\Install-RSAT.log",
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$level = "Info"
    )
    Begin {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $verbosePreference = 'Continue'
    }
    Process {
        if ((Test-Path $path)) {
            $logSize = (Get-Item -Path $path).Length/1MB
            $maxLogSize = 5
        }
        # Check for file size of the log. If greater than 5MB, it will create a new one and delete the old.
        if ((Test-Path $path) -AND $logSize -gt $maxLogSize) {
            Write-Error "Log file $path already exists and file exceeds maximum file size. Deleting the log and starting fresh."
            Remove-Item $path -Force
            New-Item $path -Force -ItemType File | Out-Null
        }
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (-NOT(Test-Path $path)) {
            Write-Verbose "Creating $path."
            New-Item $path -Force -ItemType File | Out-Null
        }
        # Format Date for our Log File
        $formattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($level) {
            'Error' {
                Write-Error $message
                $levelText = 'ERROR:'
            }
            'Warn' {
                Write-Warning $message
                $levelText = 'WARNING:'
            }
            'Info' {
                Write-Verbose $message
                $levelText = 'INFO:'
            }
        }
        # Write log entry to $Path
        "$formattedDate $levelText $message" | Out-File -FilePath $path -Append
    }
    End {
    }
}

# Create Pending Reboot function for registry
function Test-PendingRebootRegistry {
    $cbsRebootKey = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction Ignore
    $wuRebootKey = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction Ignore
    if (( $null -ne $cbsRebootKey) -OR ($null -ne $wuRebootKey)) {
        $true
    }
    else {
        $false
    }
}

# Minimum required Windows 10 build (v1809)
$Build1809 = 17763
# Get running Windows build
$windowsBuild = (Get-CimInstance -Class Win32_OperatingSystem).BuildNumber
# Look for pending reboots in the registry
$testPendingRebootRegistry = Test-PendingRebootRegistry
# Set Features on Demand local source
$FoD_Source = "C:\Source\RSAT_CAB_Files"

if ($windowsBuild -ge $Build1809) {
    Write-Log -Message "Running correct Windows 10 build number for RSAT. Build number is: $WindowsBuild"

    if ($testPendingRebootRegistry -eq $true) {
        Write-Log -Message "Reboots are pending. The script will continue, but RSAT might not install successfully"
    }

    if ($PSBoundParameters["All"]) {
        Write-Log -Message "Script is running with -All parameter. Installing all available RSAT features"
        $install = Get-WindowsCapability -Online | Where-Object {$_.Name -like "RSAT*" -AND $_.State -eq "NotPresent"}
        if ($null -ne $install) {
            foreach ($item in $install) {
                $rsatItem = $item.Name
                Write-Log -Message "Adding $rsatItem to Windows"
                try {
                    Add-WindowsCapability -Online -Name $rsatItem -Source $FoD_Source -LimitAccess
                }
                catch [System.Exception] {
                    Write-Log -Message "Failed to add $rsatItem to Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
        }
        else {
            Write-Log -Message "All RSAT features are already installed."
        }
    }
    
    if ($PSBoundParameters["Basic"]) {
        Write-Log -Message "Script is running with -Basic parameter. Installing basic RSAT features"
        $install = Get-WindowsCapability -Online | Where-Object {
            ($_.Name -like "Rsat.ActiveDirectory*" -OR
             $_.Name -like "Rsat.DHCP.Tools*" -OR
             $_.Name -like "Rsat.Dns.Tools*" -OR
             $_.Name -like "Rsat.GroupPolicy*" -OR
             $_.Name -like "Rsat.ServerManager*") -AND
             $_.State -eq "NotPresent"
        }

        if ($null -ne $install) {
            foreach ($item in $install) {
                $rsatItem = $item.Name
                Write-Log -Message "Adding $rsatItem to Windows"
                try {
                    Add-WindowsCapability -Online -Name $rsatItem -Source $FoD_Source -LimitAccess
                }
                catch [System.Exception] {
                    $global:ScriptFailed = $true
                    Write-Log -Message "Failed to add $rsatItem to Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
        }
        else {
            Write-Log -Message "BASIC RSAT features already installed."
        }
    }
    
    if ($PSBoundParameters["Uninstall_Basic"]) {
        Write-Log -Message "Script is running with -Uninstall_Basic parameter. Uninstalling Basic RSAT Features"
        $installed = Get-WindowsCapability -Online | Where-Object {
            ($_.Name -like "Rsat.ActiveDirectory*" -OR
             $_.Name -like "Rsat.DHCP.Tools*" -OR
             $_.Name -like "Rsat.Dns.Tools*" -OR
             $_.Name -like "Rsat.GroupPolicy*" -OR
             $_.Name -like "Rsat.ServerManager*") -AND
             $_.State -eq "Installed"
        }

        if ($null -ne $installed) {
            foreach ($item in $installed) {
                $rsatItem = $item.Name
                Write-Log -Message "Uninstalling $rsatItem from Windows"
                try {
                    Remove-WindowsCapability -Name $rsatItem -Online
                } 
                catch [System.Exception] {
                    $global:ScriptFailed = $true
                    Write-Log -Message "Failed to uninstall $rsatItem from Windows" -Level Warn
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn
                    
                }
             }

        }
    }

    if ($PSBoundParameters["Uninstall_All"]) {
        Write-Log -Message "Script is running with -Uninstall parameter. Uninstalling all RSAT features"
        # Querying for installed RSAT features first time
        $installed = Get-WindowsCapability -Online | Where-Object {
            $_.Name -like "Rsat*" -AND
            $_.State -eq "Installed" -AND
            $_.Name -notlike "Rsat.ServerManager*"
        }
        if ($null -ne $installed) {
            Write-Log -Message "Uninstalling the first round of RSAT features"
            # Uninstalling first round of RSAT features - some features are locked until others are uninstalled first
            foreach ($item in $installed) {
                $rsatItem = $item.Name
                Write-Log -Message "Uninstalling $rsatItem from Windows"
                try {
                    Remove-WindowsCapability -Name $rsatItem -Online
                }
                catch [System.Exception] {
                    $global:ScriptFailed = $true
                    Write-Log -Message "Failed to uninstall $rsatItem from Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            }
        }
    
        # Querying for installed RSAT features second time
        # Excluded Rsat.ServerManager as it is unremovable and throws a error
        $installed = Get-WindowsCapability -Online | Where-Object {
            $_.Name -like "Rsat*" -AND
            $_.Name -notlike "Rsat.ServerManager*" -AND
            $_.State -eq "Installed"}
        if ($null -ne $installed) { 
            Write-Log -Message "Uninstalling the second round of RSAT features"
            # Uninstalling second round of RSAT features
            foreach ($item in $installed) {
                $rsatItem = $item.Name
                Write-Log -Message "Uninstalling $rsatItem from Windows"
                try {
                    Remove-WindowsCapability -Name $rsatItem -Online
                }
                catch [System.Exception] {
                    $global:ScriptFailed = $true
                    Write-Log -Message "Failed to remove $rsatItem from Windows" -Level Warn 
                    Write-Log -Message "$($_.Exception.Message)" -Level Warn 
                }
            } 
        }
        else {
            Write-Log -Message "All RSAT features seems to be uninstalled already"
        }
    }
}
else {
    Write-Log -Message "Not running correct Windows 10 build: $windowsBuild" -Level Warn
}

if ($global:ScriptFailed) {
    Write-Log -Message "Script completed with errors." -Level Error
    exit 1
} else {
    Write-Log -Message "Script completed successfully." -Level Info
    exit 0
}