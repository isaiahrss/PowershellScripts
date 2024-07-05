<#
.SYNOPSIS
    Checks if a inbound firewall rule for exists to allow an application and if it doesn't, creates it.The firewall rule is created for TCP & UDP protocols.
    Optimized for Windows 7 Ultimate.
.DESCRIPTION
    This script checks if a firewall rule already exists for an application and creates a new inbound firewall rule for the application if it doesn't exist. 
    The script allows you to specify the applications you want to allow through the firewall by providing their names and paths. 
    The script creates firewall rules for both TCP and UDP protocols.
.PARAMETER Apps
    An array of hash tables containing the names and paths of the applications you want to allow through the firewall.
.EXAMPLE
$apps = @(
    @{ Name = "App1"; Path = "C:\Path\to\File.exe" },
    @{ Name = "App2"; Path = "C:\Path\to\File.exe" },
    @{ Name = "App3"; Path = "C:\Path\to\File.exe" }
)       
.NOTES
        Author:     ISAIAH ROSS
        Github:     https://github.com/isaiahrss 
        LinkedIn:   https://linkedin.com/in/isaiah-ross
#>


# Add the apps you want to allow through the firewall in the array. Create as many entries as needed.
$apps = @(
    @{ Name = "App1"; Path = "C:\Path\to\File.exe" },
    @{ Name = "App2"; Path = "C:\Path\to\File.exe" },
    @{ Name = "App3"; Path = "C:\Path\to\File.exe" }
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
