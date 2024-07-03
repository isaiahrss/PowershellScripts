<#
.SYNOPSIS
        Check for files and folders, create them if they don't exist, and executes a script to create a firewall rule based on Event ID 4625 in the Event Viewer logs. 
        Optimized for Windows 7 Ultimate.
.DESCRIPTION
        This script is designed to:
            1. Check if the source folder and script file exist, and create them if they don't.
            2. Retrieve Event ID 4625 from the Windows Event Viewer.
            3. Extract IP addresses from the event logs.
            4. Create a firewall rule to block RDP access from the extracted IP addresses. 
            5. Adds the IP addresses to the existing "Block RDP" rule if it exists.
            6. Log the actions and results to a uniquely named log file based on the current date and time.
.LINK 
        Github:     https://github.com/isaiahrss 
        LinkedIn:   linkedin.com/in/isaiah-ross
.PARAMETER ScriptPath
        The path to the script file to be created or executed.
.PARAMETER FolderPath
        The path to the folder where the script file will be created.
.PARAMETER LogPath
        The path to the log file where the script actions and results will be logged.   
.EXAMPLE
        Edit the $ScriptPath and $FolderPath variables with the desired paths.
        Edit the $LogPath variable with the desired path for the log file then run the script.
.NOTES
        Author: ISAIAH ROSS
#>

$ScriptPath = "C:\Path\to\script.ps1"
$FolderPath = "C:\Path\to\folder"

# Check if the folder exists, and create it if it doesn't
if (-not (Test-Path -Path $FolderPath -PathType Container)) {
    New-Item -Path $FolderPath -ItemType Directory | Out-Null
    Write-Host "Folder created: $FolderPath" -ForegroundColor Green
} else {
    Write-Host "Folder already exists: $FolderPath" -ForegroundColor Yellow
}

# Check if the script file exists, and create it if it doesn't
if (-not (Test-Path -Path $ScriptPath -PathType Leaf)) {
    $ScriptContent = @"
param (
    [int]`$EventID = 4625,  # Default to 4625 (failed logon events)
    [string]`$LogName = `"Security`"
)

# Generate a log file name based on the current date and time
`$LogPath = `"C:\Path\to\folder\log_{0}.txt`" -f (Get-Date -Format `"yyyyMMdd_HHmmss`")
Write-Host (`"Log file will be created at: {0}`" -f `$LogPath) -ForegroundColor Cyan

# Retrieve the event log
Write-Host `"Retrieving event logs...`" -ForegroundColor Cyan
try {
    `$EventLog = Get-EventLog -LogName `$LogName -InstanceId `$EventID
} catch {
    Write-Host `"An error occurred while retrieving event logs: `$_`" -ForegroundColor Red
    exit
}

# Check if any events were found
Write-Host `"Checking for event log entries...`" -ForegroundColor Cyan
if (`$null -eq `$EventLog -or `$EventLog.Count -eq 0) {
    Write-Host `'No Violations found`' -ForegroundColor Yellow
    `$LogMessage = `'No Violations found on `' + (Get-Date)
    Add-Content -Path `$LogPath -Value `$LogMessage
    exit
} else {
    Write-Host (`'Violations Found: {0} event(s)`' -f `$EventLog.Count) -ForegroundColor Red
    `$LogMessage = `'Violations Found: `' + `$EventLog.Count + `' event(s) on `' + (Get-Date)
    Add-Content -Path `$LogPath -Value `$LogMessage
}

# Extract IP addresses from event log messages and count occurrences
`$IPCount = @{}
foreach (`$entry in `$EventLog) {
    if (`$entry.Message -match "`\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b`") {
        `$IPAddress = `$matches[0]
        if (`$IPCount.ContainsKey(`$IPAddress)) {
            `$IPCount[`$IPAddress] += 1
        } else {
            `$IPCount[`$IPAddress] = 1
        }
    }
}

# Find IP addresses with at least 5 occurrences
`$FrequentIPs = `$IPCount.GetEnumerator() | Where-Object { `$_.Value -ge 5 }

# Check if any frequent IP addresses were found
if (`$FrequentIPs.Count -eq 0) {
    Write-Host `'No IP addresses with 5 or more occurrences found in the event logs`' -ForegroundColor Yellow
    `$LogMessage = `'No IP addresses with 5 or more occurrences found in the event logs on `' + (Get-Date)
    Add-Content -Path `$LogPath -Value `$LogMessage
    exit
} else {
    Write-Host "Failed Logon Threshold Exceeded!'" -ForegroundColor Yellow
    
    # Initialize COM object for firewall rules
    `$fwPolicy2 = New-Object -ComObject HNetCfg.FwPolicy2
    `$existingRule = `$fwPolicy2.Rules | Where-Object { `$_.Name -eq 'Block RDP' }
    `$newAddresses = @()

    foreach (`$ip in `$FrequentIPs) {
        `$IPAddress = `$ip.Key
        `$Subnet = `$IPAddress.Substring(0, `$IPAddress.LastIndexOf('.')) + `".0/24`"
        `$newAddresses += `$Subnet
    }

    try {
        if (`$existingRule) {
            # Update existing rule to include new IP addresses
            Write-Host "Updating existing Block RDP rule..." -ForegroundColor Cyan
            `$existingRemoteAddresses = `$existingRule.RemoteAddresses -split ","
            `$updatedRemoteAddresses = `$existingRemoteAddresses + `$newAddresses
            `$existingRule.RemoteAddresses = `$updatedRemoteAddresses -join ","
        } else {
            # Create a new rule if it doesn't exist
            Write-Host "Creating new Block RDP rule..." -ForegroundColor Cyan
            `$rule = New-Object -ComObject HNetCfg.FWRule
            `$rule.Name = 'Block RDP'
            `$rule.Description = "Block RDP from `$newAddresses"
            `$rule.Protocol = 6  # TCP
            `$rule.LocalPorts = "3389"
            `$rule.RemoteAddresses = `$newAddresses -join ","
            `$rule.Direction = 1  # Inbound
            `$rule.Enabled = `$true
            `$rule.Action = 0  # Block
            `$fwPolicy2.Rules.Add(`$rule)
        }

        `$LogMessage = 'IP addresses ' + (`$newAddresses -join ", ") + ' have been added to the Block RDP rule on ' + (Get-Date)
        Write-Host `$LogMessage -ForegroundColor Yellow
        Add-Content -Path `$LogPath -Value `$LogMessage

        Write-Host 'Firewall rule created and logged successfully' -ForegroundColor Green
    } catch {
        Write-Host "Failed to create or update firewall rule: `$_" -ForegroundColor Red
        `$LogMessage = "Failed to create or update firewall rule for IP addresses `$newAddresses on " + (Get-Date)
        Add-Content -Path `$LogPath -Value `$LogMessage
    }
}
"@
    $ScriptContent | Out-File -FilePath $ScriptPath -Encoding UTF8
    Write-Host "Script created: $ScriptPath" -ForegroundColor Green
} else {
    Write-Host "Script already exists: $ScriptPath" -ForegroundColor Yellow
}

# Execute the script
& $ScriptPath -EventID 4625 -LogName "Security"
