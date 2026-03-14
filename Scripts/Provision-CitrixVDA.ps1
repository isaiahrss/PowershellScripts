<#
.SYNOPSIS
Provision a Citrix Remote PC Delivery Group and assign a machine to a user.

.DESCRIPTION
This script automates the provisioning of a Citrix Delivery Group for Remote PC access. It integrates with Active Directory and Citrix services to:
- Sanitize and generate a delivery group name based on a user's display name.
- Validate or clean up existing delivery group or machine assignments.
- Add a machine to a Citrix machine catalog.
- Assign the user to the machine and delivery group.
- Apply Citrix access policy rules and power schemes.
- Log operations and handle errors gracefully.

.PARAMETER None
Prompts are used to collect the machine name and user credentials interactively.

.EXAMPLE
.\Provision-Citrix_v2.ps1  
Prompts for machine and user, then provisions Citrix Remote PC delivery group accordingly.

.NOTES
Author: Isaiah Ross
Created: 20205-01-08
Modified: 2025-07-16
Version: 3.0
Changes:
- Integrated Active Directory user lookup.
- Delivery group name conflict handling with cleanup.
- Improved logging and error handling.
- Adds access policies and power schemes.
- Logs operations using Start-LogHighLevelOperation and Stop-LogHighLevelOperation.

Dependencies:
- Citrix PowerShell SDK
- ActiveDirectory module
- Appropriate Citrix admin permissions

#>

# Import Citrix and Active Directory Modules
Write-Host "Importing Active Directory modules..."
Import-Module ActiveDirectory -ErrorAction Stop

function Sanitize {
    param (
        [string]$Name
    )
    # Remove invalid characters
    $Name -replace '[\/;:#.*?=<>|\[\]()"\`'']', ''
}

# Variables
$CitrixServer = "vm-citrixvadc03.contoso.org:80" 
$GetCatalog = Get-BrokerCatalog -Name "WKS - User Remote PCs" -AdminAddress "$CitrixServer"
$highLevelOp = Start-LogHighLevelOperation -Text "Provision Citrix Delivery Group" -Source "Provision-CitrixVDA.ps1" -AdminAddress $CitrixServer
$succeeded = $false

# Prompt for Machine Name
$MachineName = Read-Host "Enter the name of the machine (AD1\Machine) to be added"

# Prompt for User
$User = Read-Host "Enter the username (AD1\user) to assign to the machine"

# Retrieve Display Name of User from Active Directory
Write-Host "Retrieving display name of the user from Active Directory..."
try {
    $ADUser = Get-ADUser -Identity ($User -split '\\')[1] -Properties DisplayName -ErrorAction Stop
    $DisplayName = $ADUser.DisplayName
    Write-Host "User display name retrieved: $DisplayName"
} catch {
    Write-Error "Failed to retrieve the display name for the user. Ensure the user exists in Active Directory."
    exit
}

# Add Computer to AD Group | Fetch the computer object
$ADComputerName = $MachineName -replace ".*\\", ""  # Strip domain prefix
$ComputerObject = "$ADComputerName`$"
$ADGroup = "G_XenDesktop_FAS"
if ($ComputerObject) {
    try {
        Add-ADGroupMember -Identity $ADGroup -Members $ComputerObject -Confirm:$false
        Write-Host "$ADComputerName added to $ADGroup" -ForegroundColor Green
    } catch {
        Write-Host "Error: Failed to add $ADComputerName to $ADGroup. Error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Error: Machine $ADComputerName not found in Active Directory." -ForegroundColor Red
    Write-Host "Exiting Script" -ForegroundColor Yellow
    Exit
}

# Define Delivery Group Names
$DeliveryGroupName = "WKS - $DisplayName"

# Sanitize the Delivery Group names
$DeliveryGroupName = Sanitize -Name $DeliveryGroupName

# Check Delivery Group Name Availability
Write-Host "Checking availability of the Delivery Group name: '$DeliveryGroupName'..." -ForegroundColor Yellow

# Retrieve availability status
$DeliveryGroupAvailability = Test-BrokerDesktopGroupNameAvailable -Name $DeliveryGroupName

if ($DeliveryGroupAvailability.Available -eq $true) {
    Write-Host "The Delivery Group Name $DeliveryGroupName is available." -ForegroundColor Green
    Write-Host "Using Delivery Group name: $DeliveryGroupName. Proceeding with the script..." -ForegroundColor Cyan

} else {
    Write-Host "Delivery Group $DeliveryGroupName Already Exists!" -ForegroundColor Yellow

    Write-Host "Fetching currently assigned machine" -ForegroundColor Cyan
    $FetchMachine = Get-BrokerDesktop -DesktopGroupName $DeliveryGroupName -AdminAddress $CitrixServer

    # Skip removal if no machine is assigned
    if (-not $FetchMachine -or -not $FetchMachine.MachineName) {
        Write-Host "No machine assigned to $DeliveryGroupName. Skipping removal steps." -ForegroundColor Yellow
    } else {
        Write-Host "$($FetchMachine.MachineName) is currently assigned to the $DeliveryGroupName"  -ForegroundColor Yellow

        # Prompt to continue
        $userInput = Read-Host "Confirm if $($FetchMachine.MachineName) can be removed from $DeliveryGroupName. If not, please run Provision_Citrix-TRP.ps1 script... Do you want to remove? (Y/N)"
        if ($userInput -notin @('Y', 'y')) {
            Write-Host "Operation canceled by user." -ForegroundColor Yellow
            Exit
        } else {
            Write-Host "Removing $($FetchMachine.MachineName)" -ForegroundColor Yellow

            try {
                # Enable maintenance mode
                Set-BrokerMachine -InMaintenanceMode $true -AdminAddress $CitrixServer -MachineName $FetchMachine.MachineName -LoggingId $highLevelOp.id
                Write-Host "Maintenance Mode Enabled" -ForegroundColor Yellow

                Start-Sleep -Seconds 10

                # Remove from Desktop Group
                Remove-BrokerMachine -AdminAddress $CitrixServer -MachineName $FetchMachine.MachineName  -DesktopGroup $AssignedDesktopGroup.DesktopGroupName -LoggingId $highLevelOp.id
                Write-Host "Machine removed from Desktop Group" -ForegroundColor Green

                Start-Sleep -Seconds 10

                # Remove from Catalog
                Remove-BrokerMachine -AdminAddress $CitrixServer -Machine $FetchMachine.MachineName  -LoggingId $highLevelOp.id
                Write-Host "Machine removed from Catalog" -ForegroundColor Green

                Start-Sleep -Seconds 10
            }
            catch {
                Write-Host "Error during Machine removal: $_ . Exiting.." -ForegroundColor Red
            }
        }
    }   
}

# Check if Machine Name is Available
Write-Host "Checking if Machine Name $MachineName is available..." -ForegroundColor Yellow

# Retrieve availability status
$MachineAvailability = Test-BrokerMachineNameAvailable -MachineName $MachineName

if ($MachineAvailability.Available -eq $true) {
    Write-Host "The Machine Name $MachineName is available." -ForegroundColor Green
} else {
    Write-Host "The Machine Name $MachineName is NOT available. Attempting to remove it..." -ForegroundColor Red

    $AssignedDesktopGroup = Get-BrokerMachine -MachineName $MachineName -AdminAddress $CitrixServer

    # Determine desktop group assignment
    if ($AssignedDesktopGroup.DesktopGroupName -and $AssignedDesktopGroup.DesktopGroupName -ne '') {
        # Prompt to continue if machine is assigned
        $userInput = Read-Host "Machine is currently assigned to Desktop Group '$($AssignedDesktopGroup.DesktopGroupName)'! Confirm Machine can be removed before proceeding... Do you want to continue? (Y/N)"
        
        if ($userInput -notin @('Y', 'y')) {
            Write-Host "Operation canceled by user." -ForegroundColor Yellow
            exit
        }

        try {
            # Enable maintenance mode
            Set-BrokerMachine -InMaintenanceMode $true -AdminAddress $CitrixServer -MachineName $MachineName -LoggingId $highLevelOp.id
            Write-Host "Maintenance Mode Enabled" -ForegroundColor Yellow

            # Remove from Desktop Group
            Remove-BrokerMachine -MachineName $MachineName -DesktopGroup $AssignedDesktopGroup.DesktopGroupName -LoggingId $highLevelOp.id
            Write-Host "Machine removed from Desktop Group" -ForegroundColor Green
        }
        catch {
            Write-Host "Error during Desktop Group removal: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Machine is not assigned to any Desktop Group. Skipping group removal..." -ForegroundColor Cyan
    }

    # Final removal from Machine Catalog
    try {
        Remove-BrokerMachine -AdminAddress $CitrixServer -MachineName $MachineName -Force -ErrorAction Stop -LoggingId $highLevelOp.id
        Write-Host "Machine '$MachineName' successfully removed." -ForegroundColor Green

        # Wait timer to allow changes to apply
        Write-Host "Waiting for removal to propagate..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10

        # Retest Machine Name Availability
        Write-Host "Rechecking if Machine Name '$MachineName' is available after removal..." -ForegroundColor Yellow
        $MachineAvailability = Test-BrokerMachineNameAvailable -MachineName $MachineName
        if ($MachineAvailability.Available -eq $true) {
            Write-Host "The Machine Name '$MachineName' is now available." -ForegroundColor Green
        } else {
            Write-Error "The Machine Name '$MachineName' is still not available after removal. Exiting."
            exit
        }
    } catch {
        # Handle errors during machine removal
        Write-Error "Failed to remove Machine '$MachineName'. Error: $($_.Exception.Message)"
        exit
    }
}

if ($DeliveryGroupAvailability.Available -eq $false -and $MachineAvailability.Available) {
    # Delivery Group exists already; add machine to existing DG
    try {
        New-BrokerMachine -AdminAddress $CitrixServer `
            -CatalogUid $GetCatalog.Uid `
            -IsReserved $False `
            -MachineName $MachineName `
            -LoggingId $highLevelOp.id
        Add-BrokerMachine -AdminAddress $CitrixServer `
            -MachineName $MachineName `
            -DesktopGroup $DeliveryGroupName `
            -LoggingId $highLevelOp.id
        Add-BrokerUser -AdminAddress $CitrixServer `
            -Name $User `
            -Machine $MachineName `
            -LoggingId $highLevelOp.id

        Write-Host "$MachineNAME added to $DeliveryGroupName. $User assigned $MachineName" -ForegroundColor Green
        $succeeded = $true
        Stop-LogHighLevelOperation -HighLevelOperationId $highLevelOp.Id -IsSuccessful $succeeded
    } catch {
        Write-Host "Failed to assign user desktop. Error: $_ "
    }
} else {
    # Delivery Group name IS available; create a new DG if the machine name is available
    if ($DeliveryGroupAvailability.Available -and $MachineAvailability.Available) {

try {

# Adds Machine to Machine Catalog'
Write-Host "Adding Machine to User Remote PC catalog" -ForegroundColor Yellow
New-BrokerMachine -AdminAddress "$CitrixServer" `
                  -CatalogUid $GetCatalog.Uid `
                  -IsReserved $False `
                  -MachineName $MachineName `
                  -LoggingId $highLevelOp.id
Write-Host "Creating User Object in Citrix" -ForegroundColor Yellow
New-BrokerUser -AdminAddress "$CitrixServer" ` -Name $User
Write-Host "Assigning User to Machine" -ForegroundColor Yellow
Add-BrokerUser  -AdminAddress "$CitrixServer" ` -Name $User ` -Machine $MachineName ` -LoggingId $highLevelOp.id

# Create Delivery Group 
Write-Host "Creating Delivery Group" -ForegroundColor Yellow
New-BrokerDesktopGroup  -AdminAddress "$CitrixServer" `
                        -ColorDepth "TwentyFourBit" `
                        -DeliveryType "DesktopsOnly" `
                        -DesktopKind "Private" `
                        -InMaintenanceMode $False `
                        -IsRemotePC $True `
                        -MinimumFunctionalLevel "L7_9" `
                        -Name $DeliveryGroupName `
                        -OffPeakBufferSizePercent 10 `
                        -OffPeakDisconnectAction "Nothing" `
                        -OffPeakDisconnectTimeout 0 `
                        -OffPeakExtendedDisconnectAction "Nothing" `
                        -OffPeakExtendedDisconnectTimeout 0 `
                        -OffPeakLogOffAction "Nothing" `
                        -OffPeakLogOffTimeout 0 `
                        -PeakBufferSizePercent 10 `
                        -PeakDisconnectAction "Nothing" `
                        -PeakDisconnectTimeout 0 `
                        -PeakExtendedDisconnectAction "Nothing" `
                        -PeakExtendedDisconnectTimeout 0 `
                        -PeakLogOffAction "Nothing" `
                        -PeakLogOffTimeout 0 `
                        -PublishedName $DeliveryGroupName `
                        -Scope @() `
                        -SecureIcaRequired $False `
                        -SessionSupport "SingleSession" `
                        -ShutdownDesktopsAfterUse $False `
                        -TimeZone "Pacific Standard Time" `
                        -LoggingId $highLevelOp.id
Add-BrokerDesktopGroup  -AdminAddress "$CitrixServer"  `
                        -Name $DeliveryGroupName `
                        -RemotePCCatalog $GetCatalog.Uid `
                        -LoggingId $highLevelOp.id
Add-BrokerMachine  -AdminAddress "$CitrixServer"  `
                   -DesktopGroup $DeliveryGroupName `
                   -MachineName $MachineName `
                   -LoggingId $highLevelOp.id
 
# Create Delivery Group Policies and Schemes
Write-Host "Adding Policies and Schemes" -ForegroundColor Yellow
Test-BrokerAccessPolicyRuleNameAvailable  -AdminAddress "$CitrixServer" `  -Name @("$DeliveryGroupName-Direct")
Get-BrokerDesktopGroup -Name $DeliveryGroupName -AdminAddress "$CitrixServer" | ForEach-Object {
    New-BrokerAccessPolicyRule -AdminAddress "$CitrixServer" `
                               -AllowedConnections "NotViaAG" `
                               -AllowedProtocols @("HDX","RDP") `
                               -AllowedUsers "Filtered" `
                               -AllowRestart $True `
                               -Enabled $True `
                               -DesktopGroupUid $_.Uid `
                               -IncludedSmartAccessFilterEnabled $True `
                               -IncludedUserFilterEnabled $True `
                               -IncludedUsers $User `
                               -Name "$DeliveryGroupName-Direct" `
                               -LoggingId $highLevelOp.id
}
Test-BrokerAccessPolicyRuleNameAvailable  -AdminAddress "$CitrixServer" `  -Name @("$DeliveryGroupName-AG") 
Get-BrokerDesktopGroup -Name $DeliveryGroupName -AdminAddress "$CitrixServer" | ForEach-Object {
    New-BrokerAccessPolicyRule -AdminAddress "$CitrixServer" `
                               -AllowedConnections "ViaAG" `
                               -AllowedProtocols @("HDX","RDP") `
                               -AllowedUsers "Filtered" `
                               -AllowRestart $True `
                               -Enabled $True `
                               -DesktopGroupUid $_.Uid `
                               -IncludedSmartAccessFilterEnabled $True `
                               -IncludedSmartAccessTags @() `
                               -IncludedUserFilterEnabled $True `
                               -IncludedUsers $User `
                               -Name "$DeliveryGroupName-AG" `
                               -LoggingId $highLevelOp.id
}
Test-BrokerPowerTimeSchemeNameAvailable  -AdminAddress "$CitrixServer"  -Name @("$DeliveryGroupName-Weekdays") 
Get-BrokerDesktopGroup -Name $DeliveryGroupName -AdminAddress "$CitrixServer" | ForEach-Object {
    New-BrokerPowerTimeScheme  -AdminAddress "$CitrixServer" `
                           -DaysOfWeek "Weekdays" `
                           -DesktopGroupUid $_.Uid `
                           -DisplayName "Weekdays" `
                           -Name "$DeliveryGroupName-Weekdays" `
                           -PeakHours @($False,$False,$False,$False,$False,$False,$False,$True,$True,$True,$True,$True,$True,$True,$True,$True,$True,$True,$True,$False,$False,$False,$False,$False) `
                           -PoolSize @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) `
                           -LoggingId $highLevelOp.id 
}
Test-BrokerPowerTimeSchemeNameAvailable  -AdminAddress "$CitrixServer" `  -Name @("$DeliveryGroupName-Weekend")
Get-BrokerDesktopGroup -Name $DeliveryGroupName -AdminAddress "$CitrixServer" | ForEach-Object {
    New-BrokerPowerTimeScheme  -AdminAddress "$CitrixServer" `
                           -DaysOfWeek "Weekend" `
                           -DesktopGroupUid $_.Uid `
                           -DisplayName "Weekend" `
                           -Name "$DeliveryGroupName-Weekend" `
                           -PeakHours @($False,$False,$False,$False,$False,$False,$False,$True,$True,$True,$True,$True,$True,$True,$True,$True,$True,$True,$True,$False,$False,$False,$False,$False) `
                           -PoolSize @(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) `
                           -LoggingId $highLevelOp.id
}
# Assigning Machine to Delivery Group 
Write-Host "Creating Assignment Policy Rules" -ForegroundColor Yellow
Get-BrokerDesktopGroup -Name $DeliveryGroupName -AdminAddress "$CitrixServer" | ForEach-Object {
    New-BrokerAssignmentPolicyRule  -AdminAddress "$CitrixServer" `
                                -Description "" `
                                -Enabled $True `
                                -DesktopGroupUid $_.Uid `
                                -IncludedUserFilterEnabled $True `
                                -IncludedUsers $User `
                                -MaxDesktops 1 `
                                -Name $DeliveryGroupName `
                                -PublishedName $DeliveryGroupName `
                                -LoggingId $highLevelOp.id
}

$succeeded = $true

}

catch {
    Write-Host "An error occurred:" -ForegroundColor Red
    Write-Host "Error Message: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Error Details: $($_.Exception.InnerException)" -ForegroundColor Yellow
    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Gray

    # Optionally write full error details to a log file
    $ErrorDetails = @{
        Timestamp = (Get-Date).ToString()
        ErrorMessage = $_.Exception.Message
        InnerException = $_.Exception.InnerException
        StackTrace = $_.Exception.StackTrace
    }
    $ErrorDetails | Out-File -FilePath "C:\Source\CitrixScriptErrorLog.txt" -Append
    exit 1
}

finally{
    Write-Host "$DeliveryGroupName Provisioned for $User; $MachineName Successfully" -ForegroundColor Green
    Stop-LogHighLevelOperation -HighLevelOperationId $highLevelOp.Id -IsSuccessful $succeeded
    }
}

}