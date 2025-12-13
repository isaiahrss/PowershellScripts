<#
.SYNOPSIS
Creates a new on-premises remote mailbox, configures Active Directory settings, and prepares the mailbox for Azure AD sync and conversion to a shared mailbox.

.DESCRIPTION
Prompts the user for details needed to create a new on-premises remote mailbox, including UPN, SMTP address, and secure password. The script checks for existing mailboxes, creates the mailbox, disables email address policy, applies AD settings such as disabling the account and setting notes, and waits for Azure AD sync. Finally, it instructs the user to run a follow-up script to convert the mailbox to a shared mailbox in Exchange Online.

.PARAMETER Name
The full display name for the new mailbox (e.g., "Finance Department").

.PARAMETER LogonName
The SAM account name (username) for the mailbox. Must be under 20 characters and contain no spaces.

.PARAMETER EmailAddress
The desired primary SMTP email address for the mailbox (e.g., finance@contoso.com).

.PARAMETER TicketNumber
The ticket number associated with this mailbox creation, used in the notes field.

.PARAMETER OwnerName
The full name of the mailbox owner, used in the notes field.

.PARAMETER Password
A secure password for the new mailbox account.

.PARAMETER OU
The Organizational Unit in Active Directory where the mailbox account will be created. This is hardcoded in the script.

.EXAMPLE
PS C:\> .\Create-OnPremMailbox.ps1
Enter Full Mailbox Name (e.g., Finance Department): Finance Department
Enter Logon Name (e.g., FinanceDept). NO SPACES. MUST BE LESS THAN 20 Characters!!!: FinanceDept
Enter desired email address (e.g., finance@contoso.com): finance@contoso.com
Enter Ticket Number: INC0001234
Enter Owner Name: Jane Doe
Enter temporary password for the new mailbox: ********

.NOTES
Author: ISAIAH ROSS
GitHub: https://github.com/isaiahross
LinkedIn: https://linkedin.com/in/isaiah-ross
Last Updated: June 2024
Requirements: Exchange Management Shell, ActiveDirectory module, and Azure AD Connect.
Waits 20 minutes for AD sync to complete before prompting the user to run a follow-up script:
C:\Source\Scripts\ConvertTo-SharedMailbox.ps1
Ensure the follow-up script is run with sufficient Exchange Online permissions.
#>

# Variables (prompt or hardcode)
$Name      = Read-Host "Enter Full Mailbox Name (e.g., Finance Department)"
$LogonName     = Read-Host "Enter Logon Name (e.g., FinanceDept). NO SPACES. MUST BE LESS THAN 20 Characters!!!"
$EmailAddress  = Read-Host "Enter desired email address (e.g., finance@contoso.com)"
$TicketNumber  = Read-Host "Enter Ticket Number"
$OwnerName     = Read-Host "Enter Owner Name"
$Password = Read-Host "Enter temporary password for the new mailbox" -AsSecureString
$OU            = "contonso.org/Resources/Mailboxes"
$UPN           = "$LogonName@contonso.org"  # Adjust your domain
$Notes         = "$TicketNumber, Owner $OwnerName"

# Check if the mailbox already exists
if (Get-Mailbox -Filter "Name -eq '$FullName'" -ErrorAction SilentlyContinue) {
    Write-Host "Mailbox with name '$FullName' already exists." -ForegroundColor Yellow
    exit
}

# Create new on-premises user mailbox
New-RemoteMailbox -UserPrincipalName $UPN `
            -Name $Name `
            -OnPremisesOrganizationalUnit $OU `
            -SamAccountName $LogonName `
            -Password $Password `
            -DisplayName $Name `
            -PrimarySmtpAddress $EmailAddress `
            -ResetPasswordOnNextLogon $false

# Prevent automatic email address overwrite
Set-RemoteMailbox -Identity $EmailAddress -EmailAddressPolicyEnabled $false

Write-Host "Mailbox for $FullName created." -ForegroundColor Green

# Wait for AD to process the object
Write-Host "Waiting 10 seconds for AD replication..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Apply AD settings
$adUser = Get-ADUser -Identity $LogonName -Properties telephoneNumber, info

# Set 'User cannot change password' and 'Password never expires'
Set-ADUser $adUser -CannotChangePassword $true
Set-ADUser $adUser -PasswordNeverExpires $true

# Disable the user account
Disable-ADAccount $adUser

# Add note to Telephones > Notes section
Set-ADUser $adUser -Replace @{info = $Notes}

Write-Host "AD configuration completed." -ForegroundColor Cyan

Write-Host "Waiting 20 minutes for Azure AD Sync..." -ForegroundColor Yellow
Start-Sleep -Seconds 1200

Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host "AD Sync period has ended." -ForegroundColor Green
Write-Host "Please run the following script manually in a standard PowerShell session (not EMS):" -ForegroundColor Yellow
Write-Host "    C:\Source\Scripts\ConvertTo-SharedMailbox.ps1" -ForegroundColor Cyan
Write-Host "Make sure to run as a user with Exchange Online permissions." -ForegroundColor Magenta
Write-Host "----------------------------------------" -ForegroundColor Cyan



