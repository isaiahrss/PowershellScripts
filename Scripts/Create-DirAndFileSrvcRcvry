<#
.SYNOPSIS
    Creates files and folders if they do not exist, and sets the service failure actions and recovery command for the specified service. 
    Opimized for Windows 10 and later.
.DESCRIPTION
    This script checks if a file and folder exists, and if not creates it with values. 
    It also sets the service failure actions and recovery command for the specified service. 
    Includes WhatIf parameter to show what would happen if the command were to run.
    Edit the ServiceName string in the content array to match the service name variable.
    Comment out the -WhatIf switch on Line 94 to run without the parameter.
.PARAMETER FilePath1
    The path to the file to create.
.PARAMETER Content1
    The content to add to the file.
.PARAMETER WhatIf
    Shows what would happen if the command were to run. 
.PARAMETER ServiceName1
    The name of the service to set the failure actions and recovery command.
.PARAMETER ScriptPath1
    The path to the script to run on service failure.
.NOTES
    Author:     ISAIAH ROSS
    Github:     https://github.com/isaiahrss
    LinkedIn:   https://linkedin.com/in/isaiah-ross
#>

function CheckAndCreateFiles {
    param (
        [string]$FilePath1 = "C:\Path\to\File.ps1",
        [string]$Content1 = @"
Restart-Service -Name ServiceName

if ($?) {
    Write-Host 'ServiceName service restarted successfully.' -ForegroundColor Green
} else {
    Write-Host 'Service failed to restart.' -ForegroundColor Red
}
"@,
        [switch]$WhatIf
    )

    $filesCreated = @()
    $filePaths = @($FilePath1)
    $contents = @($Content1)

    for ($i = 0; $i -lt $filePaths.Count; $i++) {
        $filePath = $filePaths[$i]
        $content = $contents[$i]

        if (-not (Test-Path -Path $filePath)) {
            $parentDirectory = Split-Path -Path $filePath -Parent
            if (-not (Test-Path -Path $parentDirectory)) {
                New-Item -Path $parentDirectory -ItemType Directory -WhatIf:$WhatIf
            }

            Set-Content -Path $filePath -Value $content -WhatIf:$WhatIf
            Write-Host "File created and content added: $filePath" -ForegroundColor Green
            $filesCreated += $true
        } else {
            Write-Host "File already exists: $filePath" -ForegroundColor Yellow
            $filesCreated += $false
        }
    }

    return $filesCreated
}

function SetServiceRecovery {
    param (
        [string]$ServiceName1 = "ServiceName",
        [string]$ScriptPath1 = "C:\Path\to\File.ps1",
        [switch]$WhatIf
    )

    $filesCreatedResult = CheckAndCreateFiles -FilePath1 $ScriptPath1 -Content1 @"
Restart-Service -Name ServiceName

if ($?) {
    Write-Host 'ServiceName service restarted successfully.' -ForegroundColor Green
} else {
    Write-Host 'Service failed to restart.' -ForegroundColor Red
}
"@ -WhatIf:$WhatIf

    $serviceName = $ServiceName1
    $scriptPath = $ScriptPath1

    if ($filesCreatedResult[0] -or (Test-Path -Path $scriptPath)) {
        try {
            # Set the service failure actions
            if (-not $WhatIf) {
                $arguments = "failure $serviceName reset= 60 actions= run/5000/restart/5000/restart/5000 command= '$scriptPath'"
                $command = "sc.exe $arguments"
                $output = Invoke-Expression $command

                if ($output -match "\[SC\] ChangeServiceConfig2 SUCCESS") {
                    Write-Host "Service failure actions and recovery command set successfully for $serviceName." -ForegroundColor Green
                } else {
                    Write-Host "Failed to set service failure actions and recovery command for $serviceName. Output: $output" -ForegroundColor Red
                }
            } else {
                Write-Host "WhatIf: Would set service failure actions and recovery command for $serviceName." -ForegroundColor Green
            }
        } catch {
            Write-Host "Failed to set service failure actions and recovery command for $serviceName. Exception: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Failed to set service failure actions and recovery command for $serviceName because the file creation failed." -ForegroundColor Red
    }
}

# Usage example
SetServiceRecovery #-WhatIf
