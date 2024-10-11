# Function to silently handle errors and continue the script
cls
function Silently-Execute {
    param ([scriptblock]$Command)
    try {
        & $Command
    } catch {
        $null # Ignore errors, continue script
    }
}

function Monitor-DownloadsForFile {
    param (
        [string]$TargetFile,
        [string]$TempLogFile
    )

    $downloadsPath = [System.IO.Path]::Combine($env:USERPROFILE, 'Downloads')

    Write-Host "Monitoring Downloads folder: $downloadsPath for $TargetFile"

    # Monitor the Downloads folder for new files and log filenames
    while (-Not (Test-Path "$downloadsPath\$TargetFile")) {
        $currentFiles = Get-ChildItem -Path $downloadsPath -File | Select-Object -ExpandProperty Name

        # Log new files to temp log file
        foreach ($file in $currentFiles) {
            if (-Not (Select-String -Path $TempLogFile -Pattern $file)) {
                Add-Content -Path $TempLogFile -Value $file
                Write-Host "New file detected: $file"
            }
        }

        # Check if the target file exists
        if (Test-Path "$downloadsPath\$TargetFile") {
            Write-Host "$TargetFile found in Downloads folder."
            return "$downloadsPath\$TargetFile"
        }

        Start-Sleep -Seconds 5
    }
}

function Run-InstallerAsAdmin {
    param (
        [string]$FilePath,
        [string]$Arguments
    )

    if (Test-Path $FilePath) {
        Write-Host "Running installer as Administrator with arguments: $Arguments"
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$FilePath`" $Arguments" -Verb RunAs -Wait
    } else {
        Write-Host "Installer file not found."
    }
}

function Invoke-FileDownload {
    param (
        [string]$Url,
        [string]$Destination,
        [string]$TaskName
    )

    Write-Host "Downloading $TaskName from $Url"
    $response = Silently-Execute { Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -PassThru }

    if (-not $response) {
        Write-Host "Failed to download $TaskName. No response received."
        return
    }

    $contentLength = $response.Headers["Content-Length"]
    if (-not $contentLength) {
        Write-Host "Failed to retrieve content length. Download progress cannot be tracked."
        return
    }

    $downloadedBytes = 0
    while ($downloadedBytes -lt $contentLength) {
        $downloadedBytes = (Get-Item $Destination).length
        $progress = [math]::round(($downloadedBytes / $contentLength) * 100)
        Write-Progress -Activity "Downloading $TaskName" -Status "$progress% Completed" -PercentComplete $progress
        Start-Sleep -Milliseconds 100
    }
}

function Check-Command {
    param ([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to show progress for elapsed time and estimated time
function Show-ElapsedTimeProgress {
    param ([int]$ElapsedTime, [int]$TotalTime)
    $progress = [math]::round(($ElapsedTime / $TotalTime) * 100)
    Write-Progress -Id 1 -Activity "Elapsed Time" -Status "$ElapsedTime seconds" -PercentComplete $progress
}

function Show-EstimatedTimeProgress {
    param ([int]$ElapsedTime, [int]$EstimatedTime)
    $progress = [math]::round(($ElapsedTime / $EstimatedTime) * 100)
    Write-Progress -Id 2 -Activity "Estimated Time Remaining" -Status "$EstimatedTime seconds total" -PercentComplete $progress
}

# Main script execution

# WampServer download link and parameters
$wampDownloadUrl = "https://wampserver.aviatechno.net/files/install/wampserver3.3.5_x64.exe"
$wampInstallerPath = "$env:USERPROFILE\Downloads\wampserver3.3.5_x64.exe"
$tempLogFile = "$env:TEMP\downloaded_files_log.txt"

# Download WampServer
Silently-Execute { Invoke-FileDownload -Url $wampDownloadUrl -Destination $wampInstallerPath -TaskName "WampServer" }

# Run the WampServer installer silently as Administrator
Silently-Execute { Run-InstallerAsAdmin -FilePath $wampInstallerPath -Arguments '/DIR="C:\wamp" /VERYSILENT /SUPPRESSMSGBOXES' }

# OpenSSL download link and parameters
$opensslDownloadUrl = "https://slproweb.com/download/Win64OpenSSL_Light-3_3_2.msi"
$opensslInstallerPath = "$env:USERPROFILE\Downloads\Win64OpenSSL_Light-3_3_2.msi"
$installPath = "C:\gooch\var\php-slip"
$opensslPath = "$installPath\openssl\bin\openssl.exe"

# Check if OpenSSL is installed
if (-Not (Check-Command "openssl") -and -Not (Test-Path $opensslPath)) {
    Write-Host "OpenSSL not found, downloading and installing OpenSSL."
    Silently-Execute { Invoke-FileDownload -Url $opensslDownloadUrl -Destination $opensslInstallerPath -TaskName "OpenSSL" }

    if (Test-Path $opensslInstallerPath) {
        Write-Progress -Id 3 -Activity "Installing OpenSSL" -Status "Installing..." -PercentComplete 0
        Silently-Execute { Start-Process -FilePath $opensslInstallerPath -ArgumentList "/quiet" -Wait }
        Write-Progress -Id 3 -Activity "Installing OpenSSL" -Status "Installation Complete" -PercentComplete 100
        $opensslPath = "$installPath\openssl\bin\openssl.exe"
    } else {
        Write-Host "OpenSSL installer not found. The file might not have been downloaded correctly."
    }
} else {
    Write-Host "OpenSSL is already installed."
}

# Monitor progress for elapsed and estimated time
$scriptStartTime = Get-Date
$estimatedTotalTime = 300 # Adjust estimated total time in seconds (e.g., 5 minutes)
$elapsedTime = 0

while ($elapsedTime -lt $estimatedTotalTime) {
    $elapsedTime = (Get-Date) - $scriptStartTime
    Show-ElapsedTimeProgress -ElapsedTime $elapsedTime.Seconds -TotalTime $estimatedTotalTime
    Show-EstimatedTimeProgress -ElapsedTime $elapsedTime.Seconds -EstimatedTime $estimatedTotalTime
    Start-Sleep -Seconds 1
}

Write-Host "Script completed."
