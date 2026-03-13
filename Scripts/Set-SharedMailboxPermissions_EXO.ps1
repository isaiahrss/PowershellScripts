<#
.SYNOPSIS
Assigns permissions to users for a shared mailbox in Exchange Online.

.DESCRIPTION
Prompts the admin to enter a shared mailbox email address and iteratively assign selected permissions (Full Access, Send As, Send on Behalf, or combinations) to one or more users. Each permission assignment is wrapped in error handling to ensure feedback on success or failure.

.PARAMETER Mailbox
The shared mailbox email address to which permissions will be assigned.

.PARAMETER User
The email address of the user to be granted permissions. Entered interactively in a loop.

.EXAMPLE
PS C:\> .\Set-SharedMailboxPermissions.ps1
Enter the shared mailbox email address (e.g., finance@contoso.com): finance@contoso.com
Enter user email to assign permissions (or press Enter to finish): john.doe@contoso.com
Select permission to assign for john.doe@contoso.com:
1. Full Access
2. Send As
3. Send on Behalf
4. Full Access + Send As
5. Full Access + Send on Behalf

.NOTES
Author: ISAIAH ROSS
GitHub: https://github.com/isaiahross
LinkedIn: https://linkedin.com/in/isaiah-ross
Last Updated: June 2024
Requirements: Exchange Online PowerShell module (e.g., via Connect-ExchangeOnline).
Ensure the executing user has sufficient permissions to assign mailbox permissions.
Supports assigning permissions to multiple users in one session.
#>

# Connect to Exchange Online
Connect-ExchangeOnline

# Prompt for shared mailbox 
$Mailbox = Read-Host "Enter the shared mailbox email address (e.g., finance@contoso.com)"

# Prompt for users and permissions
do {
    $User = Read-Host "Enter user email to assign permissions (or press Enter to finish)"
    if ([string]::IsNullOrWhiteSpace($User)) { break }

    Write-Host "Select permission to assign for $User"
    Write-Host "1. Full Access"
    Write-Host "2. Send As"
    Write-Host "3. Send on Behalf"
    Write-Host "4. Full Access + Send As"
    Write-Host "5. Full Access + Send on Behalf"

    $choice = Read-Host "Enter number of your choice"

    switch ($choice) {
        '1' {
            try {
                Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -InheritanceType All -ErrorAction Stop
                Write-Host "Full Access granted to $User" -ForegroundColor Green
            } catch {
                Write-Host "Failed to grant Full Access to $User. Error: $_" -ForegroundColor Red
            }
        }
        '2' {
            try {
                Add-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop
                Write-Host "Send As granted to $User" -ForegroundColor Green
            } catch {
                Write-Host "Failed to grant Send As to $User. Error: $_" -ForegroundColor Red
            }
        }
        '3' {
            try {
                Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Add = $User} -ErrorAction Stop
                Write-Host "Send on Behalf granted to $User" -ForegroundColor Green
            } catch {
                Write-Host "Failed to grant Send on Behalf to $User. Error: $_" -ForegroundColor Red
            }
        }
        '4' {
            try {
                Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -InheritanceType All -ErrorAction Stop
                Add-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop
                Write-Host "Full Access and Send As granted to $User" -ForegroundColor Green
            } catch {
                Write-Host "Failed to grant Full Access + Send As to $User. Error: $_" -ForegroundColor Red
            }
        }
        '5' {
            try {
                Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -InheritanceType All -ErrorAction Stop
                Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Add = $User} -ErrorAction Stop
                Write-Host "Full Access and Send on Behalf granted to $User" -ForegroundColor Green
            } catch {
                Write-Host "Failed to grant Full Access + Send on Behalf to $User. Error: $_" -ForegroundColor Red
            }
        }
    }

} while ($true)

Write-Host "Permission assignment complete." -ForegroundColor Cyan

#disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false
