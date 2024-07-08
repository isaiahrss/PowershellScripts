<#
.SYNOPSIS
    Applies folder permissions to a group on multiple folders.
.DESCRIPTION
    Specifies the group to add to the folder permissions, the permission to grant, and the folders to apply the permissions to.
.PARAMETER FolderPaths
    An array of folder paths to apply the permissions to.
.PARAMETER Group
    The group to add to the folder permissions.
.PARAMETER Permission
    The permission to grant to the group.
.NOTES
    Author:     ISAIAH ROSS
    Github:     https://github.com/isaiahrss
    LinkedIn:   https://linkedin.com/in/isaiah-ross
#>

# Define the folder paths and the group
$folderPaths = @("C:\Path\to\folder", "C:\Path\to\folder", "C:\Path\to\folder")
$group = "DOMAIN\Group"

# Define the permission rule
$permission = "Permission"

foreach ($folderPath in $folderPaths) {
    # Check if the folder exists
    if (Test-Path $folderPath) {
        # Get the folder security settings
        $acl = Get-Acl $folderPath

        # Check if the permission already exists
        $existingRule = $acl.Access | Where-Object {
            $_.IdentityReference -eq $group -and
            ($_.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Modify) -eq [System.Security.AccessControl.FileSystemRights]::Modify -and
            $_.AccessControlType -eq "Allow"
        }

        if ($existingRule) {
            Write-Output "Permission 'Modify' already exists for '$group' on '$folderPath'."
        } else {
            # Create a new access rule
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($group, $permission, "ContainerInherit,ObjectInherit", "None", "Allow")

            # Add the access rule to the folder
            $acl.SetAccessRule($accessRule)

            # Apply the new security settings to the folder
            Set-Acl $folderPath $acl

            Write-Output "Permissions applied successfully to $folderPath."
        }
    } else {
        Write-Output "Folder does not exist: $folderPath"
    }
}
