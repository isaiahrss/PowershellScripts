<#
.SYNOPSIS
    Checks if a outbound firewall rule for exists to allow an application to communicate with a IP and if it doesn't, creates it.
    The firewall rule is created for TCP & UDP protocols.
    Optimized for Windows 7 Ultimate.

.DESCRIPTION
    This script checks if a firewall rule already exists for an application to communicate with a IP and creates a new outbound firewall rule for the application if it doesn't exist.
    The script allows you to specify the IP addresses you want to allow outbound connections to.
    The script creates firewall rules for both TCP and UDP protocols.  

.PARAMETER IPAddresses
    An array of IP addresses you want to allow outbound connections to.

.PARAMETER RuleName
    The name of the firewall rule to be created.

.PARAMETER LogPath
    The path to the log file where the script actions and results will be logged.

.NOTES
    Author:     ISAIAH ROSS
    Github:     https://github.com/isaiahrss 
    LinkedIn:   https://linkedin.com/in/isaiah-ross
    
.#>

# Define the list of IP addresses to allow outbound connections to
# Add the IP addresses you want to allow outbound connections to in the array. Create as many entries as needed.
$allowedIPAddresses = @(
    "xx.x.xx.xxx", "xx.x.xx.xxx", "xx.x.xx.xxx"
)

$ruleName = "Allow_Outbound_IPs"

# Validate a single IP address
function Validate-IP {
    param (
        [string]$ip
    )
    if ($ip -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
        return $true
    } else {
        return $false
    }
}

# Function to add an IP address to the firewall rule
function Add-IPToFirewallRule {
    param (
        [string]$ip
    )
    try {
        Write-Host "Attempting to add IP: $ip" -ForegroundColor Cyan
        netsh advfirewall firewall add rule name=$ruleName dir=out action=allow protocol=any remoteip=$ip
        Write-Host "Successfully added IP: $ip" -ForegroundColor Green
    } catch {
        Write-Host "Error adding IP: $ip - $_" -ForegroundColor Red
    }
}

# Check if the rule exists
$existingRule = netsh advfirewall firewall show rule name=$ruleName | Select-String -Pattern $ruleName

if ($existingRule) {
    Write-Host "Rule already exists. Clearing the rule to re-add IPs." -ForegroundColor Yellow
    netsh advfirewall firewall delete rule name=$ruleName
}

# Add each IP address individually
foreach ($ip in $allowedIPAddresses) {
    if (Validate-IP -ip $ip) {
        Add-IPToFirewallRule -ip $ip
    } else {
        Write-Host "Invalid IP address detected and ignored: $ip" -ForegroundColor Yellow
    }
}

Write-Host "Outbound connections to the specified IP addresses have been allowed." -ForegroundColor Green
