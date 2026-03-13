<#
.SYNOPSIS
Enables a remote Office 365 mailbox and assigns a Microsoft 365 license to a specified user or AD group.

.DESCRIPTION
This script provisions a remote mailbox in Exchange Online for either a single user or members of an AD group, ensuring the user’s OU is synchronized by Azure AD Connect. It verifies the user or group input, checks for existing mailboxes, and enables the remote mailbox if needed. It also adds the user to the specified M365 license group and waits for synchronization.

.PARAMETER ADGroupName
(Optional) Name of the AD group (must start with "G_O365_G") whose members will be processed.

.PARAMETER User
(Optional) The SAM account name of the individual user to be provisioned.

.PARAMETER O365License
The AD security group that corresponds to the appropriate Microsoft 365 license assignment.

.EXAMPLE
PS C:\> .\Provision-O365Mailbox.ps1 -User jdoe -O365License "G_O365_G_E3"

.EXAMPLE
PS C:\> .\Provision-O365Mailbox.ps1 -ADGroupName "G_O365_G_E1_SyncOnly" -O365License "G_O365_G_E1_SyncOnly"

.NOTES
Author: ISAIAH ROSS
GitHub: https://github.com/isaiahross
LinkedIn: https://linkedin.com/in/isaiah-ross
Last Updated: [Date]  

Behavior:
- Only one of `-ADGroupName` or `-User` should be used per execution.
- Validates that the user’s OU is within a hardcoded DirSync list.
- Logs all output to a file in the format: yyyyMMdd-provisionO365Mailbox.log.
- Appends log entries for auditing and troubleshooting.
- Adds user to M365 license group.
- Waits 20 minutes for Azure AD sync before prompting further manual steps.

Requirements:
- Active Directory module
- Hybrid Exchange setup with remote mailbox capability
- AD group-based M365 license assignment model

Post-Sync Reminder:
- Script ends with a reminder to run `setM365MailboxOptions.ps1` manually in Exchange Online PowerShell.
#>

# Prompts for username and licence group if not executed with paramters
param(
    [string]$ADGroupName,
    [string]$User,
    [string]$O365License
)

if (-not $User) {
    $User = Read-Host "Enter Username"
}

if (-not $O365License) {
    $O365License = Read-Host "Enter M365 License Type"
}


Import-Module ActiveDirectory

#Set Date and Log file
$date = get-date -Format yyyyMMdd
$logFile = "$date-provisionO365Mailbox.log"
$csvdate = get-date -Format yyyyMMddTHHmmss
$startDate = get-date
Add-Content $logFile "==================================================================="
Add-Content $logFile "Start: $startDate"

# Create ADConnect DirSync OU list/array # Hardcode based on your environment
$DirSync = @(
    'OU=Site1,DC=contonso,DC=org',
    'OU=Site2,DC=contonso,DC=org',
    'OU=Site3,DC=contonso,DC=org',
    'OU=Site4,DC=contonso,DC=org',
    'OU=Mailboxes,OU=Resources,DC=contonso,DC=org',
    'OU=Rooms,OU=Resources,DC=contonso,DC=org',
    'OU=O365,OU=Test,DC=contonso,DC=org',
    'OU=eDiscovery,OU=O365,OU=Resources,DC=contonso,DC=org',
    'OU=PhoneSystem,OU=O365,OU=Resources,DC=contonso,DC=org'
)

# Check Parameters and get users
If (($ADGroupName) -and ($user)){
    Write-Host "Error: please use only one parameter -ADGroupName or -User!!" -ForegroundColor Red -BackgroundColor Yellow
    Add-Content $logFile "Error: please use only one parameter -ADGroupName or -User!!"
    Add-Content $logFile "==================================================================="
    $endDate = get-date
    Add-Content $logFile "End: $endDate"
    Add-Content $logFile "==================================================================="
    exit
}
ElseIf ($ADGroupName){
    If ($ADGroupName -notlike "G_O365_G*"){
        Write-Host "License Group is not valid: $ADGroupName" -ForegroundColor Red -BackgroundColor Yellow
        Add-Content $logFile "License Group is not valid: $ADGroupName"
        Add-Content $logFile "==================================================================="
        $endDate = get-date
        Add-Content $logFile "End: $endDate"
        Add-Content $logFile "==================================================================="
        exit
    }
    $users = @()  
    $users = Get-ADGroupMember -Identity $ADGroupName | Where-Object { $_.objectClass -eq 'user' } | Get-ADUser -Properties * | select DisplayName,samAccountName,UserPrincipalName,mail
    $userCount = $users.count
    If ($userCount -gt 0){
        Write-Host "Users found: $userCount" -ForegroundColor Green
        Write-Host "Executing against: $ADGroupName" -ForegroundColor Green
        Add-Content $logFile "License Group: $ADGroupName"
        Add-Content $logFile "Users found: $userCount"
        Add-Content $logFile "==================================================================="
    }
    else{
        Write-Host "Users found: $userCount" -ForegroundColor Red
        Write-Host "Cannot execute against: $ADGroupName" -ForegroundColor Red
        Add-Content $logFile "License Group: $ADGroupName"
        Add-Content $logFile "Users found: $userCount"
        Add-Content $logFile "==================================================================="
    }
}
ElseIf ($User){
    $users = @()  
    $users = Get-ADUser -identity $User -Properties * | select DisplayName,samAccountName,UserPrincipalName,mail
    Write-Host "Executing against: $user" -ForegroundColor Green
    Add-Content $logFile "Executing against: $user"
    Add-Content $logFile "==================================================================="
}
Else{
    Write-Host "Please provide one of two parameters: -ADGroupName or -User" -ForegroundColor Red -BackgroundColor Yellow
    Add-Content $logFile "No parameters provided.  No action taken."
    Add-Content $logFile "==================================================================="
    $endDate = get-date
    Add-Content $logFile "End: $endDate"
    Add-Content $logFile "==================================================================="
    exit
}

#Check and assign RemoteMailbox
$users | Foreach-Object{
    $mail = $_.mail
    $upn = $_.UserPrincipalName
    $userName = $_.samAccountName

    If (($mail) -and (Get-RemoteMailbox -identity $mail -ErrorAction SilentlyContinue)){
        Write-Host "Remote Mailbox already enabled for $mail" -ForegroundColor Yellow
        if(!$ADGroupName){
            Add-Content $logFile "Remote Mailbox already enabled for $mail"
        }
    }
    elseIf (($mail) -and (Get-Mailbox -identity $mail -ErrorAction SilentlyContinue)){
        Write-Host "Found on premise mailbox for $mail" -ForegroundColor Red
        Add-Content $logFile "Found on premise mailbox for $mail"
    }
    else{
        #verify user OU is part of ADConnect DirSync
        $userCN = Get-ADUser -Identity $userName -Properties CanonicalName
        $userOU = "OU=" + ($userCN.DistinguishedName -split ",OU=",2)[1]
        
        if($DirSync -match $userOU){
            Write-Host "OU is in DirSync List: $userOU" -ForegroundColor Green
            Add-Content $logFile "OU is in DirSync List: $userOU"
            
            #verify samAccountName matches UPN and proper suffix
            $chkUPN = "$userName@contonso.org"

            if ($upn -eq $chkUpn){
            Write-Host "Enabling remote mailbox for $upn" -ForegroundColor Green
            Add-Content $logFile "Enabling remote mailbox for $upn"
            #Syntax is: Enable-RemoteMailbox <user> �RemoteRoutingAddress <user@tenant.mail.onmicrosoft.com>
            Enable-RemoteMailbox -Identity $username -RemoteRoutingAddress $username@contonso.mail.onmicrosoft.com
            Write-Host "Mailbox enabled for $User. Please wait 20 mins for AD Sync" -ForegroundColor Green
            }
            else{
                Write-Host "Error: Cannot enable remote mailbox for $upn" -BackgroundColor Black -ForegroundColor Red
                Add-Content $logFile "Error: Cannot enable remote mailbox for $upn"
            }
        }
        Else{
            Write-Host "OU is not in DirSync list: $userOU" -ForegroundColor Red
            Add-Content $logFile "OU is not in DirSync list: $userOU"
        }
    }
} 

# Assigns O365 License
try {
    Add-ADGroupMember -Identity $O365License -Members $User
    Write-Host "Added $User to $O365License" -ForegroundColor Green
} catch {
    Write-Host "Failed to add $User to $O365License" -ForegroundColor Red
    Add-Content $logFile "Failed to add $user to $O365License. Error: $_"
}

# Wait timer for AD Sync
Write-Host "Waiting 20 minutes for Azure AD Sync..." -ForegroundColor Yellow
Start-Sleep -Seconds 1200

Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "AD Sync period has ended." -ForegroundColor Green
Write-Host "Please run the following script manually in a standard PowerShell session (not EMS) and connect to exchange online:" -ForegroundColor Yellow
Write-Host "    .\setM365MailboxOptions.ps1 -mailbox 'JDoe' " -ForegroundColor Cyan
Write-Host "Make sure to run as a user with Exchange Online permissions." -ForegroundColor Magenta
Write-Host "----------------------------------------" -ForegroundColor Cyan
Add-Content $logFile "Wait timer ended, mailbox now exists in EXO"

$endDate = get-date
Add-Content $logFile "==================================================================="
Add-Content $logFile "End: $endDate"
Add-Content $logFile "==================================================================="

