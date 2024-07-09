<#
.SYNOPSIS
    Backup bookmarks from Chrome, Edge, and Firefox for all user profiles on the local machine.
.DESCRIPTION
    This script backs up bookmarks from Chrome, Edge, and Firefox for all user profiles on the local machine.
    The bookmarks are saved to a network location in separate directories for each browser.
    The script excludes certain user profiles (Administrator, Public, Default) from the backup. You can add more profiles to exclude as needed.
    The backup location is defined by the $networkDrive variable.
.NOTES
    Author:     ISAIAH ROSS
    Github:     https://github.com/isaiahrss
    LinkedIn:   https://linkedin.com/in/isaiah-ross
#>

# Network backup base location
$networkDrive = "\\Network\Drive\Here"

# Get the computer name
$computerName = $env:COMPUTERNAME

# Define the local user profiles directory, typically C:\Users
$userProfiles = "C:\Users"

# List of user profiles to exclude
$excludeProfiles = @("Administrator", "Public", "Default", "etc")

# Get all user profile directories, excluding specified profiles
$profileDirs = Get-ChildItem $userProfiles -Directory | Where-Object { $excludeProfiles -notcontains $_.Name }

foreach ($profileDir in $profileDirs) {
    $userName = $profileDir.Name
    # Define the backup paths for each browser in this user profile
    $chromeBookmarks = "$profileDir\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    $edgeBookmarks = "$profileDir\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    $firefoxProfilePath = "$profileDir\AppData\Roaming\Mozilla\Firefox\Profiles"

    # Create backup directories if they don't exist
    $chromeBackupPath = "$networkDrive\$computerName\$userName\Chrome"
    $edgeBackupPath = "$networkDrive\$computerName\$userName\Edge"
    $firefoxBackupPath = "$networkDrive\$computerName\$userName\Firefox"
    New-Item -Path $chromeBackupPath, $edgeBackupPath, $firefoxBackupPath -ItemType Directory -Force
    Write-Host "Backing up bookmarks for user: $userName" -ForegroundColor Cyan

    # Backup Chrome bookmarks
    if (Test-Path $chromeBookmarks) {
        Copy-Item $chromeBookmarks -Destination "$chromeBackupPath\Bookmarks" -Force
    }

    # Backup Edge bookmarks
    if (Test-Path $edgeBookmarks) {
        Copy-Item $edgeBookmarks -Destination "$edgeBackupPath\Bookmarks" -Force
    }

    # Backup Firefox bookmarks (only if Firefox is installed and profiles exist)
    if (Test-Path $firefoxProfilePath) {
        $firefoxProfile = Get-ChildItem $firefoxProfilePath -Directory | Where-Object { $_.Name -like "*.default-release" } | Select -First 1
        if ($firefoxProfile) {
            $firefoxDataPath = "$firefoxProfilePath\$($firefoxProfile.Name)\places.sqlite"
            if (Test-Path $firefoxDataPath) {
                Copy-Item $firefoxDataPath -Destination "$firefoxBackupPath\places.sqlite" -Force
            }
        }
    }
}

Write-Host "Bookmarks backup completed successfully." -ForegroundColor Green
