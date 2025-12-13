<#
.SYNOPSIS
Retrieves an Active Directory user object using an ambiguous name resolution (ANR) search.

.DESCRIPTION
Prompts the user to input a user's name (e.g., "John Doe") and attempts to retrieve the corresponding Active Directory user object using an LDAP filter with ANR. Displays an error message if the retrieval fails.

.PARAMETER name
The display name of the user to search for. This is entered interactively at runtime.

.EXAMPLE
PS C:\> .\Find-ADUserByName.ps1
Enter name of User (e.g. John Doe): Jane Smith

.NOTES
Author: ISAIAH ROSS
GitHub: https://github.com/isaiahross
Last Updated: June 2024
#>

$name = Read-Host "Enter name of User (e.g. John Doe)"

try {
    Get-ADUser -LDAPFilter "(anr=$name)" -Properties SamAccountName 
} catch {
    Write-Host "Retrieval failed. Double check name of user" -ForegroundColor Red
    exit
}
