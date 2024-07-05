<#
.SYNOPSIS
    Checks if a inbound firewall rule for exists to allow an application and if it doesn't, creates it.The firewall rule is created for TCP & UDP protocols.
    Optimized for Windows 10 and Later.
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

# Import the NetSecurity module
if (-not (Get-Module -Name NetSecurity)) {
    Import-Module -Name NetSecurity
}

# Define an array of apps with their paths
$apps = @(
    @{ Name = "App1"; Path = "C:\Path\to\File.exe" },
    @{ Name = "App2"; Path = "C:\Path\to\File.exe" },
    @{ Name = "App3"; Path = "C:\Path\to\File.exe" }
)

# Hash table to store existing firewall rules
$FirewallRuleHash = @{}

# Function to check if a firewall rule exists
function CheckFirewallRule {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    if ($FirewallRuleHash.ContainsKey($DisplayName)) {
        Write-Host "Firewall rule '$DisplayName' exists." -ForegroundColor Yellow
        return $true
    }
    return $false
}

# Function to create a new firewall rule
function CreateFirewallRule {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$Program,
        [Parameter(Mandatory = $true)]
        [string]$Protocol
    )

    if (-not (CheckFirewallRule -DisplayName $DisplayName)) {
        try {
            New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol $Protocol -Program $Program
            Write-Host "Firewall rule created successfully for '$DisplayName'." -ForegroundColor Green

            # Update the hash table to include the newly created rule
            $FirewallRuleHash[$DisplayName] = $true
        }
        catch {
            Write-Host "Failed to create firewall rule for '$DisplayName'. Error: $_" -ForegroundColor Red
        }
    }
}

# Populate hash table with existing firewall rules
Get-NetFirewallRule | ForEach-Object {
    $FirewallRuleHash[$_.DisplayName] = $true
}

# Iterate through each application and manage firewall rules
foreach ($app in $apps) {
    $appName = $app.Name
    $appPath = $app.Path

    # Create firewall rules for TCP and UDP protocols if they don't exist
    CreateFirewallRule -DisplayName "$appName TCP" -Program $appPath -Protocol "TCP"
    CreateFirewallRule -DisplayName "$appName UDP" -Program $appPath -Protocol "UDP"
}
