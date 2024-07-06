<#
.SYNOPSIS
    Checks if a outbound firewall rule for exists to allow an application to communicate with a IP and if it doesn't, creates it.
    Optimized for Windows 10 and Later.

.DESCRIPTION
    This script checks if a firewall rule already exists for an application to communicate with a IP and creates a new outbound firewall rule for the application if it doesn't exist.
    The script allows you to specify the IP addresses you want to allow outbound connections to.
    The script creates firewall rules for both TCP and UDP protocols.  

.PARAMETER allowedIPAddresses
    An array of IP addresses you want to allow outbound connections to.

.PARAMETER RuleName
    The name of the firewall rule to be created.

.NOTES
    Author:     ISAIAH ROSS
    Github:     https://github.com/isaiahrss 
    LinkedIn:   linkedin.com/in/isaiah-ross
    
.#>

# Define the list of IP addresses to allow outbound connections to
$allowedIPAddresses = @(
    "xx.xx.xxx", #website.com
    "xx.xx.xxx", #website.com
    "xx.xx.xxx" #website.com
)

# Function to normalize IP addresses (remove CIDR notation)
function Normalize-IP {
    param (
        [string]$ip
    )
    if ($ip -match "/") {
        return $ip.Split('/')[0]
    }
    return $ip
}

# Function to get existing IPs from the firewall rule
function Get-ExistingIPs {
    param (
        [string]$name
    )
    try {
        $existingRule = netsh advfirewall firewall show rule name="$name" verbose | Select-String -Pattern "RemoteIP"
        if ($existingRule) {
            $existingIPs = $existingRule -replace ".*: (.*)", '$1'
            $existingIPs = $existingIPs -split ',' | ForEach-Object { Normalize-IP $_.Trim() }
            Write-Host "Existing IPs: $($existingIPs -join ', ')" -ForegroundColor Cyan
            return $existingIPs
        }
        return @()
    } catch {
        Write-Host "Error retrieving existing IPs: $_" -ForegroundColor Red
        return @()
    }
}

# Function to update the firewall rule
function Update-FirewallRule {
    param (
        [string]$name,
        [string[]]$newIPs
    )

    $existingIPs = Get-ExistingIPs -name $name
    $existingIPsHash = @{}
    foreach ($ip in $existingIPs) {
        $existingIPsHash[$ip] = $true
    }

    $updatedIPs = $existingIPs
    $newlyAddedIPs = @()

    foreach ($ip in $newIPs) {
        $normalizedIP = Normalize-IP $ip
        if (-not $existingIPsHash.ContainsKey($normalizedIP)) {
            $existingIPsHash[$normalizedIP] = $true
            $updatedIPs += $normalizedIP
            $newlyAddedIPs += $normalizedIP
        } else {
            Write-Host "IP: $normalizedIP already exists in the rule" -ForegroundColor Yellow
        }
    }

    if ($newlyAddedIPs.Count -eq 0) {
        Write-Host "All IPs already exist in the rule. No new IPs added." -ForegroundColor Yellow
        return
    }

    $ipList = $updatedIPs -join ","
    $command = "netsh advfirewall firewall set rule name=`"$name`" new remoteip=`"$ipList`""
    Invoke-Expression -Command $command
    Write-Host "Added IPs: $($newlyAddedIPs -join ', ') to rule" -ForegroundColor Green
}

# Check if the rule already exists
$existingRule = netsh advfirewall firewall show rule name="AllowOutboundIPs" verbose | Select-String -Pattern "AllowOutboundIPs"

if ($existingRule) {
    # Update the rule with new IPs
    Update-FirewallRule -name "AllowOutboundIPs" -newIPs $allowedIPAddresses
} else {
    # Create a new rule to allow outbound connections to the specified IP addresses
    $ipAddressList = $allowedIPAddresses -join ','
    $addRuleCommand = "netsh advfirewall firewall add rule name=`"AllowOutboundIPs`" dir=out action=allow remoteip=`"$ipAddressList`""
    Invoke-Expression -Command $addRuleCommand
    Write-Host "New rule created with the specified IP addresses." -ForegroundColor Green
}

Write-Host "Outbound connections to the specified IP addresses have been allowed." -ForegroundColor Cyan
