<#
.SYNOPSIS
Adds a specified computer to an Active Directory security group.

.DESCRIPTION
Prompts the user for a computer name, appends a trailing dollar sign to form the correct AD computer object name, and adds it to a predefined Active Directory group (e.g., for software deployment or access control).

.PARAMETER ComputerName
The NetBIOS name of the computer to be added to the AD group. Entered without the trailing `$`.

.EXAMPLE
PS C:\> .\Add-ComputerToGroup.ps1
Enter the computer name to add: WS12345
Computer WS12345 successfully added to group 

.NOTES
Author: ISAIAH ROSS
GitHub: https://github.com/isaiahross   
LinkedIn: https://linkedin.com/in/isaiah-ross
Last Updated: June 2024
Requirements: ActiveDirectory module must be installed and available.
Ensure the executing user has permissions to modify group membership in Active Directory.
#>

# Begin Script Logic
Import-Module ActiveDirectory -ErrorAction Stop

# Prompt for user and computer names
$ComputerName = Read-Host "Enter the computer name to add"

# Fetch the computer object
$ComputerNameWithDollar = "$ComputerName`$"

# AD Group
$ADGroup = "[Name of Your AD Group Here]"  # Replace with your actual AD group name

# Add the computer to the computer group
try {
    Add-ADGroupMember -Identity $ADGroup -Members $ComputerNameWithDollar
    Write-Host "Computer $ComputerName successfully added to group $ADGroup." -ForegroundColor Green
} catch {
    Write-Host "Failed to add computer $ComputerName to group $ADGroup. Error: $_" -ForegroundColor Red
}