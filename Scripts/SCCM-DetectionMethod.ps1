<#
.SYNOPSIS
    The script retrieves a list of installed applications from two registry paths. 
    Outputs a message and exit code based on the result of the query.
.DESCRIPTION
    This PowerShell script checks if a specified application is installed on a computer by querying the registry for installed applications. 
    It examines both the 32-bit and 64-bit registry paths for installed applications and filters the results to see if the specified application is present. 
    Based on the presence of the specified application the script outputs an appropriate message and sets the exit code accordingly.
    For use in the detection method of a SCCM/MECM application, remove the if/else statement, exit code and write-output. Then replace with a single $return statement. 
.PARAMETER App
    The name of the application to check for.
.PARAMETER installedApps
    The list of installed applications retrieved from the registry.
.LINK 
    https://learn.microsoft.com/en-us/mem/configmgr/apps/deploy-use/create-applications#bkmk_dt-detect
.NOTES
    Author:     ISAIAH ROSS
    Github:     https://github.com/isaiahrss
    LinkedIn:   https://linkedin.com/in/isaiah-ross
#>

# Get installed applications from registry
$installedApps = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" `
                 , "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
                 Select-Object DisplayName, DisplayVersion, Publisher, InstallDate

# Check for application using -like
$App = $installedApps | Where-Object { $_.DisplayName -like "*Put\AppName\Here*" }

# Output the result and set the exit code
if ($App) {
    Write-Output "Application is installed on this computer."
    exit 0
} else {
    Write-Output "Application is not installed on this computer."
    exit 1
}

#  Replace or comment-out the if/else statement , exit code and write-output above with the single $return statement below for use in SCCM/MECM detection method.
<#
    if ($App) {
        return $true
    }
    #> 