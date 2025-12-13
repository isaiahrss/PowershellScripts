<#
.SYNOPSIS
Creates a new Distribution Group in Exchange and optionally adds members to it.

.DESCRIPTION
Prompts the user for necessary information to create a new Distribution Group, including display name, alias, OU, and membership restrictions. Sets the provided administrator as the group owner and records the ticket number and owner details in the notes. After creation, the script allows adding members interactively.

.PARAMETER DisplayName
The display name for the new distribution group.

.PARAMETER Alias
The alias for the distribution group.

.PARAMETER OU
The Organizational Unit where the distribution group will be created (e.g., "domain.com/Groups/Marketing").

.PARAMETER TicketNumber
The ticket number used for reference, added to the group's notes.

.PARAMETER Admin
The SAM account name of the admin creating the group. Will be assigned as the group's manager.

.PARAMETER Owner
The full name of the group owner, used in the notes field.

.PARAMETER JoinApproval
Specifies whether users can freely join the group ("Open") or require approval ("Closed").

.PARAMETER LeaveApproval
Specifies whether users can leave the group freely ("Open") or not ("Closed").

.EXAMPLE
PS C:\> .\Create-DistroGroup_Onprem.ps1
Enter the Display Name for the Distribution Group (i.e, Distro Group): Marketing Team
Enter the Alias (i.e., DistroGroup): MarketingTeam
Enter the Organizational Unit (e.g., 'domain.com/Groups/Marketing'): domain.com/Groups/Marketing
Enter the Ticket Number for Note: INC123456
The Tech creating the DL. Will be set as Owner. (i.e., JDoe): JDoe
Enter the owner's Full Name: Phil Jackson (Entered in Notes)
Should owner approval be required to join? (Open/Closed): Closed
Should members be able to leave freely? (Open/Closed): Open

.NOTES
Author: ISAIAH ROSS
GitHub: https://github.com/isaiahross
LinkedIn: https://linkedin.com/in/isaiah-ross
Last Updated: June 2024
Requirements: Exchange Online or on-prem Exchange management tools.
The script interactively adds members after creating the group.
#>

# Prompt for distribution group information
$DisplayName = Read-Host "Enter the Display Name for the Distribution Group (i.e, Distro Group)"
$Alias = Read-Host "Enter the Alias (i.e., DistroGroup)"
$OU = Read-Host "Enter the Organizational Unit (e.g., 'domain.com/Groups/Marketing')"
$TicketNumber = Read-Host "Enter the Ticket Number for Note"
$Admin = Read-Host "The Tech creating the DL. Will be set as Owner. (i.e., JDoe)"
$Owner = Read-Host "Enter the owner's Full Name"
$JoinApproval = Read-Host "Should owner approval be required to join? (Open/Closed)"
$LeaveApproval = Read-Host "Should members be able to leave freely? (Open/Closed)"

# Construct note and create the group
$Note = "$TicketNumber Owner: $Owner"

try {
    New-DistributionGroup -Name $DisplayName `
                          -DisplayName $DisplayName `
                          -Alias $Alias `
                          -OrganizationalUnit $OU `
                          -ManagedBy $Admin `
                          -Notes $Note `
                          -MemberJoinRestriction $JoinApproval `
                          -MemberDepartRestriction $LeaveApproval `
                          -Type Distribution

    Write-Host "Distribution group $DisplayName created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create distribution group: $_" -ForegroundColor Red
    return
}

# Prompt to add members
do {
    $Member = Read-Host "Enter a user to add as a member (press Enter to finish)"
    if ([string]::IsNullOrWhiteSpace($Member)) { break }

    try {
        Add-DistributionGroupMember -Identity $DisplayName -Member $Member -ErrorAction Stop
        Write-Host "Added $Member to $DisplayName" -ForegroundColor Cyan
    } catch {
        Write-Host "Failed to add $Member. Error: $_" -ForegroundColor Red
    }

} while ($true)

Write-Host "Distribution group setup complete" -ForegroundColor Yellow
