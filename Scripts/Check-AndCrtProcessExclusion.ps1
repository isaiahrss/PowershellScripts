<#
.SYNOPSIS
Check-AndCrtProcessExclusion.ps1

.DESCRIPTION
Checks if Exlusion exists within Windows Defender for a process and if it doesn't, creates it. 

The script works for:
Powershell (All Versions)

.LINK
Add this later

.NOTES
Written by: ISAIAH ROSS
Website:    Add this later
LinkedIn:   linkedin.com/in/isaiah-ross

.CHANGELOG
V1.00, 06/05/2023 - Initial version
V1.10, 06/05/2023 - Added Process Paths to script
#>

$processPaths = @(
    "C:\Program Files\Intel\EMA Agent\EMAAgent.exe"
    # Add more process paths as needed
)

$defenderKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes"

foreach ($processPath in $processPaths) {
    $processName = (Get-Item $processPath).BaseName

    # Check if the exclusion already exists
    $existingExclusion = Get-ItemProperty -Path $defenderKeyPath -Name $processName -ErrorAction SilentlyContinue

    if ($null -eq $existingExclusion  ) {
        # Add the process name as an exclusion
        Add-RegKeyProperty -Key $defenderKeyPath -Name $processName -Value $true -PropertyType DWORD | Out-Null

        Write-Host "Process exclusion added successfully for: $processName" -ForegroundColor Green
    } else {
        Write-Host "Process exclusions already exist for: $processName" -ForegroundColor Yellow
    }
}

# Disable real-time monitoring temporarily to apply the changes immediately
Set-MpPreference -DisableRealtimeMonitoring $true
