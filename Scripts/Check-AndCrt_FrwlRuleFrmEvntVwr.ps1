<#
.SYNOPSIS
        Check for files and folders, create them if they don't exist, and execute a script to create a firewall rule based on Event ID 4625 in the Event Viewer logs.
.DESCRIPTION
        This script is designed to:
            1. Check if the source folder and script file exist, and create them if they don't.
            2. Retrieve Event ID 4625 from the Windows Event Viewer.
            3. Extract IP addresses from the event logs.
            4. Create a firewall rule to block RDP access from the extracted IP addresses.
            5. Log the actions and results to a uniquely named log file based on the current date and time.
.LINK 
        Github:     https://github.com/isaiahrss 
        LinkedIn:   linkedin.com/in/isaiah-ross

.PARAMETER ScriptPath
        The path to the script file to be created or executed.

.PARAMETER FolderPath
        The path to the folder where the script file will be created.

.NOTES
        Author: ISAIAH ROSS
#>

$ScriptPath = "C:\Path\To\File"
$FolderPath = "C:\Path\To\File"

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
`$LogPath = `"C:\Path\to\file\log_{0}.txt`" -f (Get-Date -Format `"yyyyMMdd_HHmmss`")
Write-Host (`"Log file will be created at: {0}`" -f `$LogPath) -ForegroundColor Cyan

# Retrieve the event log
Write-Host `"Retrieving event logs...`" -ForegroundColor Cyan
`$EventLog = Get-WinEvent -FilterHashtable @{
    LogName = `$LogName
    ID = `$EventID
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

# Debugging output
Write-Host `'Processing event logs...`' -ForegroundColor Cyan

`$IPAddress = `$null
`$XmlData = `$EventLog.ToXml()

# Debugging output
Write-Host `'Event logs converted to XML`' -ForegroundColor Cyan

# Define the XML tag to search for the IP address
`$XmlTag = `'<Data Name="IpAddress">`'

if (`$XmlData -contains `$XmlTag) {
    Write-Host `'Searching for IP address in the event logs...`' -ForegroundColor Cyan
    `$StartIndex = `$XmlData.IndexOf(`$XmlTag) + `$XmlTag.Length
    `$EndIndex = `$XmlData.IndexOf(`'</Data>`', `$StartIndex)
    `$IPAddress = `$XmlData.Substring(`$StartIndex, `$EndIndex - `$StartIndex)

    # Debugging output
    Write-Host (`"Extracted IP address: {0}`" -f `$IPAddress) -ForegroundColor Cyan
}

if (`$null -ne `$IPAddress) {
    `$Subnet = `$IPAddress.Substring(0, `$IPAddress.LastIndexOf('.')) + `".0/24`"
    `$FirewallRuleName = `'Block RDP from `' + `$Subnet
    
    try {
        Write-Host `"Creating firewall rule...`" -ForegroundColor Cyan
        New-NetFirewallRule -DisplayName `$FirewallRuleName -Direction Inbound -LocalPort 3389 -Protocol TCP -RemoteAddress `$Subnet -Action Block -Enabled True
        
        `$LogMessage = `'IP address `' + `$IPAddress + `' has been added to the Block RDP rule on `' + (Get-Date)
        Write-Host `$LogMessage -ForegroundColor Yellow
        Add-Content -Path `$LogPath -Value `$LogMessage

        # Debugging output
        Write-Host `'Firewall rule created and logged successfully`' -ForegroundColor Green
    } catch {
        Write-Host `"Failed to create firewall rule: `$_`" -ForegroundColor Red
        `$LogMessage = `"Failed to create firewall rule for IP address `$IPAddress on `" + (Get-Date)
        Add-Content -Path `$LogPath -Value `$LogMessage
    }
} else {
    Write-Host `'No IP address found in the event logs`' -ForegroundColor Yellow
    `$LogMessage = `'No IP address found in the event logs on `' + (Get-Date)
    Add-Content -Path `$LogPath -Value `$LogMessage
}
"@
    $ScriptContent | Out-File -FilePath $ScriptPath -Encoding UTF8
    Write-Host "Script created: $ScriptPath" -ForegroundColor Green
} else {
    Write-Host "Script already exists: $ScriptPath" -ForegroundColor Yellow
}

# Execute the script
& $ScriptPath -EventID 4625 -LogName "Security"




