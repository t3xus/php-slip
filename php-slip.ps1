cls

Write-Host "`n"
Write-Host "`n"
Write-Host "`n"
Write-Host "`n"
Write-Host "`n"
Write-Host "`n"

$host.UI.RawUI.BackgroundColor = "DarkBlue"
$host.UI.RawUI.ForegroundColor = "White"
Clear-Host

Write-Host "Copyright (c) 2024 James Gooch" -ForegroundColor Cyan

Write-Host ""
Write-Host "`n"
Write-Host "`n"

Write-Host "PHP-SLIP: Initiating download and installation process..." -ForegroundColor Green
Write-Host ""
Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  _ __  | |_    _ __   ___   ___ | | (_)  _ __  " -ForegroundColor Cyan
Write-Host " | '_ \ | ' \  | '_ \ |___| (_-< | | | | | '_ \\" -ForegroundColor Cyan
Write-Host " | .__/ |_||_| | .__/       /__/ |_| |_| | .__/ " -ForegroundColor Cyan
Write-Host " |_|           |_|                       |_|    " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Yellow


function Silently-Execute {
    param ([scriptblock]$Command)
    try {
        & $Command
    } catch {
        Write-Host "An error occurred, but the script will continue." -ForegroundColor Red
        $null # Ignore errors, continue script
    }
}

function Monitor-DownloadsForFile {
    param (
        [string]$TargetFile,
        [string]$TempLogFile
    )

    $downloadsPath = [System.IO.Path]::Combine($env:USERPROFILE, 'Downloads')
    Write-Host "Monitoring the Downloads folder for $TargetFile..." -ForegroundColor Yellow

    while (-Not (Test-Path "$downloadsPath\$TargetFile")) {
        $currentFiles = Get-ChildItem -Path $downloadsPath -File | Select-Object -ExpandProperty Name

        foreach ($file in $currentFiles) {
            if (-Not (Select-String -Path $TempLogFile -Pattern $file)) {
                Add-Content -Path $TempLogFile -Value $file
                Write-Host "New file detected: $file" -ForegroundColor Cyan
            }
        }

        if (Test-Path "$downloadsPath\$TargetFile") {
            Write-Host "$TargetFile found in Downloads folder." -ForegroundColor Green
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
        Write-Host "Running installer as Administrator..." -ForegroundColor Cyan
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$FilePath`" $Arguments" -Verb RunAs -Wait
    } else {
        Write-Host "Installer file not found." -ForegroundColor Red
    }
}

function Invoke-FileDownload {
    param (
        [string]$Url,
        [string]$Destination,
        [string]$TaskName
    )

    Write-Host "Downloading $TaskName from $Url..." -ForegroundColor Yellow
    $response = Silently-Execute { Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -PassThru }

    if (-not $response) {
        Write-Host "Failed to download $TaskName. No response received." -ForegroundColor Red
        return
    }

    $contentLength = $response.Headers["Content-Length"]
    if (-not $contentLength) {
        Write-Host "Failed to retrieve content length for $TaskName." -ForegroundColor Red
        return
    }

    $downloadedBytes = 0
    while ($downloadedBytes -lt $contentLength) {
        $downloadedBytes = (Get-Item $Destination).length
        $progress = [math]::round(($downloadedBytes / $contentLength) * 100)
        Write-Progress -Activity "Downloading $TaskName" -Status "$progress% Completed" -PercentComplete $progress
        Start-Sleep -Milliseconds 100
    }
    Write-Host "$TaskName download complete." -ForegroundColor Green
}

function Check-Command {
    param ([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

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


$wampDownloadUrl = "https://wampserver.aviatechno.net/files/install/wampserver3.3.5_x64.exe"
$wampInstallerPath = "$env:USERPROFILE\Downloads\wampserver3.3.5_x64.exe"
$tempLogFile = "$env:TEMP\downloaded_files_log.txt"

Silently-Execute { Invoke-FileDownload -Url $wampDownloadUrl -Destination $wampInstallerPath -TaskName "WampServer" }
Silently-Execute { Run-InstallerAsAdmin -FilePath $wampInstallerPath -Arguments '/DIR="C:\wamp" /VERYSILENT /SUPPRESSMSGBOXES' }

$opensslDownloadUrl = "https://slproweb.com/download/Win64OpenSSL_Light-3_3_2.msi"
$opensslInstallerPath = "$env:USERPROFILE\Downloads\Win64OpenSSL_Light-3_3_2.msi"
$installPath = "C:\gooch\var\php-slip"
$opensslPath = "$installPath\openssl\bin\openssl.exe"

if (-Not (Check-Command "openssl") -and -Not (Test-Path $opensslPath)) {
    Write-Host "OpenSSL not found, downloading and installing OpenSSL..." -ForegroundColor Yellow
    Silently-Execute { Invoke-FileDownload -Url $opensslDownloadUrl -Destination $opensslInstallerPath -TaskName "OpenSSL" }

    if (Test-Path $opensslInstallerPath) {
        Write-Progress -Id 3 -Activity "Installing OpenSSL" -Status "Installing..." -PercentComplete 0
        Silently-Execute { Start-Process -FilePath $opensslInstallerPath -ArgumentList "/quiet" -Wait }
        Write-Progress -Id 3 -Activity "Installing OpenSSL" -Status "Installation Complete" -PercentComplete 100
        $opensslPath = "$installPath\openssl\bin\openssl.exe"
        Write-Host "OpenSSL installation complete." -ForegroundColor Green
    } else {
        Write-Host "OpenSSL installer not found. The file might not have been downloaded correctly." -ForegroundColor Red
    }
} else {
    Write-Host "OpenSSL is already installed." -ForegroundColor Green
}

$scriptStartTime = Get-Date
$estimatedTotalTime = 130
$elapsedTime = 0

while ($elapsedTime -lt $estimatedTotalTime) {
    $elapsedTime = (Get-Date) - $scriptStartTime
    Show-ElapsedTimeProgress -ElapsedTime $elapsedTime.Seconds -TotalTime $estimatedTotalTime
    Show-EstimatedTimeProgress -ElapsedTime $elapsedTime.Seconds -EstimatedTime $estimatedTotalTime
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "All tasks completed successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Yellow
