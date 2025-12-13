<#
.SYNOPSIS
Updates the specified Active Directory user's CustomAttribute3 to "ActiveSync".

.DESCRIPTION
Prompts the user to enter a SAM account name and updates the corresponding Active Directory user's `extensionAttribute3` (also known as CustomAttribute3) with the value "ActiveSync".

.PARAMETER sam
The SAM account name of the Active Directory user to be updated. This value is entered by the user at runtime.

.EXAMPLE
PS C:\> .\Update-UserAttribute.ps1
Enter the SAM name of the user: jdoe

.NOTES
Author: Isaiah Ross
GitHub: https://github.com/isaiahross
Last Updated: June 2024

#>

# Import the Active Directory module
Import-Module ActiveDirectory

# Prompt the user to input the UPN
$sam = Read-Host "Enter the SAM name of the user"

# Update the Active Directory user's CustomAttribute3 with "ActiveSync"
Set-ADUser -Identity $sam -Replace @{extensionAttribute3="ActiveSync"}



