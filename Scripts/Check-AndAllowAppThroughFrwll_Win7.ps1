<#
.SYNOPSIS
Check-AndAllowAppThroughFrwll.ps1

.DESCRIPTION
Checks if a inbound firewall rule for exists to allow an application and if it doesn't, creates it.The firewall rule is created for TCP & UDP protocols. 
At the moment, the function to check for rule existance does not work. However, rules are created according to the array.  

The script works for:
Powershell (All Versions)

.LINK
Add this later

.NOTES
Written by: ISAIAH ROSS
Website:    Add this later
LinkedIn:   linkedin.com/in/isaiah-ross

.CHANGELOG
V1.00, 06/05/2023 - Initial version
V1.10, 06/05/2023 - Added Process Paths to script
V1.20, 06/06/2023 - Switched "Any" data value with wildcard character "*"
V1.30, 06/06/2023 - Moved $null -eq to left side of variable $existingRuleTCP
V1.40, 06/07/2023 - Added hash table to import firewall rule. Increases processing speed significantly
V1.50, 06/07/2023 - function to check if firewall rule exists, does not work. However, script works as intended despite mishap.
#>

# Define an array of apps with their paths
# Define an array of apps with their names and paths
$apps = @(
    @{ Name = "Agent.Package.Availability"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\Agent.Package.Availability\Agent.Package.Availability.exe" },
    @{ Name = "Agent.Package.IotPoc"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\Agent.Package.IotPoc\Agent.Package.IotPoc.exe" },
    @{ Name = "AgentPackageADRemote"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageADRemote\AgentPackageADRemote.exe" },
    @{ Name = "AgentPackageAgentInformation"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageAgentInformation\AgentPackageAgentInformation.exe" },
    @{ Name = "AgentPackageDiskManagement"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageDiskManagement\AgentPackageDiskManagement.exe" },
    @{ Name = "AgentPackageHeartbeat"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageHeartbeat\AgentPackageHeartbeat.exe" },
    @{ Name = "AgentPackageInternalPoller"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageInternalPoller\AgentPackageInternalPoller.exe" },
    @{ Name = "AgentPackageMarketplace"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageMarketplace\AgentPackageMarketplace.exe" },
    @{ Name = "AgentPackageMonitoring"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageMonitoring\AgentPackageMonitoring.exe" },
    @{ Name = "AgentPackageNetworkDiscovery"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageNetworkDiscovery\AgentPackageNetworkDiscovery.exe" },
    @{ Name = "AgentPackageNetworkDiscoveryWG"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageNetworkDiscoveryWG\AgentPackageNetworkDiscoveryWG.exe" },
    @{ Name = "AgentPackageOsUpdates"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageOsUpdates\AgentPackageOsUpdates.exe" },
    @{ Name = "AgentPackageProgramManagement"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageProgramManagement\AgentPackageProgramManagement.exe" },
    @{ Name = "AgentPackageRunCommandInteractive"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageRunCommandInteractive\AgentPackageRunCommandInteractive.exe" },
    @{ Name = "AgentPackageRuntimeInstaller"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageRuntimeInstaller\AgentPackageRuntimeInstaller.exe" },
    @{ Name = "AgentPackageSCRemote"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageSCRemote\AgentPackageSCRemote.exe" },
    @{ Name = "AgentPackageSTRemote"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageSTRemote\AgentPackageSTRemote.exe" },
    @{ Name = "AgentPackageSystemTools"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageSystemTools\AgentPackageSystemTools.exe" },
    @{ Name = "AgentPackageTaskScheduler"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageTaskScheduler\AgentPackageTaskScheduler.exe" },
    @{ Name = "AgentPackageTicketing"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageTicketing\AgentPackageTicketing.exe" },
    @{ Name = "AgentPackageUpgradeAgent"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageUpgradeAgent\AgentPackageUpgradeAgent.exe" },
    @{ Name = "AgentPackageWindowsUpdate"; Path = "C:\Program Files\ATERA Networks\AteraAgent\Packages\AgentPackageWindowsUpdate\AgentPackageWindowsUpdate.exe" }
)

# Import the WFAS module
Import-Module NetSecurity

# Get current firewall rules and store in a hash table
$FirewallRuleHash = @{}
Get-NetFirewallRule | ForEach-Object {
    $FirewallRuleHash[$_.DisplayName] = $_
}

# Function to check if a firewall rule exists
function FirewallRuleExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$Program,
        [Parameter(Mandatory = $true)]
        [string]$Protocol
    )

    $rule = $FirewallRuleHash[$DisplayName]
    if ($null -ne $rule) {
        if ($rule.Program -eq $Program -and $rule.Protocol -eq $Protocol) {
            return $true
        }
    }
    return $false
}

foreach ($app in $apps) {
    $appName = $app.Name
    $appPath = $app.Path

    # Check if the firewall rule already exists for TCP protocol
    $existingRuleTCP = FirewallRuleExists -DisplayName "$appName TCP" -Program $appPath -Protocol "TCP"

    if ($existingRuleTCP) {
        Write-Host "Firewall rule already exists for $appName (TCP)." -ForegroundColor Yellow
    }
    else {
        try {
            # Create a new inbound firewall rule for the app in TCP protocol
            New-NetFirewallRule -DisplayName "$appName TCP" -Direction Inbound -Action Allow -Protocol TCP -LocalPort Any -RemotePort Any -Program $appPath
            Write-Host "Firewall rule created successfully for $appName (TCP)." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to create firewall rule for $appName (TCP): $_" -ForegroundColor Red
        }
    }

    # Check if the firewall rule already exists for UDP protocol
    $existingRuleUDP = FirewallRuleExists -DisplayName "$appName UDP" -Program $appPath -Protocol "UDP"

    if ($existingRuleUDP) {
        Write-Host "Firewall rule already exists for $appName (UDP)." -ForegroundColor Yellow
    }
    else {
        try {
            # Create a new inbound firewall rule for the app in UDP protocol
            New-NetFirewallRule -DisplayName "$appName UDP" -Direction Inbound -Action Allow -Protocol UDP -LocalPort Any -RemotePort Any -Program $appPath
            Write-Host "Firewall rule created successfully for $appName (UDP)." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to create firewall rule for $appName (UDP): $_" -ForegroundColor Red
        }
    }
}
