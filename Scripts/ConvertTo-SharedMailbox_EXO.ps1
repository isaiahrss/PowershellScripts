<#
.SYNOPSIS
Converts a user mailbox to a shared mailbox in Exchange Online and assigns appropriate permissions to users.

.DESCRIPTION
Connects to Exchange Online, prompts for a mailbox to convert to a shared mailbox, and then interactively allows assignment of Full Access, Send As, or Send on Behalf permissions to specified users. Includes options for combined permission sets.

.PARAMETER Mailbox
The email address of the user mailbox to be converted to a shared mailbox.

.PARAMETER User
Email address of the user to be granted permissions on the shared mailbox. Prompted interactively in a loop until the user presses Enter.

.EXAMPLE
PS C:\> .\ConvertTo-SharedMailbox.ps1
Enter the mailbox email address to convert (e.g., finance@contoso.com): finance@contoso.com
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
Requirements: Exchange Online PowerShell module (Connect-ExchangeOnline).
Make sure the executing account has sufficient permissions to modify mailboxes and set permissions.
This script is typically run after creating and syncing a new remote mailbox from on-prem to Exchange Online.
#>

# Connect to Exchange Online
Connect-ExchangeOnline

# Prompt for mailbox to convert
$Mailbox = Read-Host "Enter the mailbox email address to convert (e.g., finance@contoso.com)"

# Convert to shared mailbox
try {
    Set-Mailbox -Identity $Mailbox -Type Shared
    Write-Host "Mailbox '$Mailbox' successfully converted to Shared." -ForegroundColor Green
} catch {
    Write-Warning "Failed to convert mailbox: $_"
    exit
}

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
            Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -InheritanceType All
        }
        '2' {
            Add-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false
        }
        '3' {
            Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Add = $User}
        }
        '4' {
            Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -InheritanceType All
            Add-RecipientPermission -Identity $Mailbox -Trustee $User -AccessRights SendAs -Confirm:$false
        }
        '5' {
            Add-MailboxPermission -Identity $Mailbox -User $User -AccessRights FullAccess -InheritanceType All
            Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo @{Add = $User}
        }
        default {
            Write-Host "Invalid choice. Skipping $User." -ForegroundColor Red
        }
    }

} while ($true)

Write-Host "Permission assignment complete." -ForegroundColor Cyan
