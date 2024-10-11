<#
.SYNOPSIS
    Silent Installation of WampServer and OpenSSL for PHP Application Deployment in Windows 11 ISOs  
.DESCRIPTION
    This script automates the installation and configuration of WampServer, OpenSSL, and Apache to serve php-slip.php. 
        - Installs WampServer silently (if not installed).
        - Installs OpenSSL (if not installed) for SSL certificate generation.
        - Serve PHP from (C:\gooch\var\php-slip).
        - Configures Apache to listen on a custom port (8778).
        - Generate self-signed SSL certificates using OpenSSL.
        - Set up a firewall rule to allow traffic on the custom port.
        - Restart WampServer services to apply all configurations.
.PARAMETER wampInstallerUrl
    URL for downloading the WampServer installer.
.PARAMETER wampInstallerPath
    Path where the WampServer installer will be saved and run from.
.PARAMETER installPath
    Directory where WampServer will be installed.
.PARAMETER phpDir
    Directory where PHP files will be served from.
.PARAMETER port
    The port Apache will use to serve the web application.
.PARAMETER opensslPath
    Path to OpenSSL executable (bundled with WampServer or installed separately).
.PARAMETER opensslDownloadUrl
    URL for downloading the OpenSSL installer.
.PARAMETER opensslInstallerPath
    Path where the OpenSSL installer will be saved and run from.
.PARAMETER phpFilePath
    Path to the PHP file that will be created to handle file uploads and DISM operations.
.PARAMETER phpFileContent
    Content of the PHP script that will be served from the specified directory.
.EXAMPLE
    Run this script as Administrator to automatically set up WampServer, OpenSSL, and a PHP application:
    
    .\setup-wampserver.ps1

.NOTES
    Author: J.Gooch
    Version: 1.8
    License: MIT License
#>

$wampInstallerUrl = "https://sourceforge.net/projects/wampserver/files/WampServer%203/Wampserver%203.2.6/wampserver3.2.6_x64.exe/download"
$wampInstallerPath = "C:\gooch\var\php-slip\wampserver-installer.exe"
$installPath = "C:\gooch\var\php-slip"
$phpDir = "C:\gooch\var\php-slip"
$port = 8778
$opensslPath = "$installPath\wamp64\bin\apache\apache2.4.46\bin\openssl.exe"
$opensslDownloadUrl = "https://slproweb.com/download/Win64OpenSSL-1_1_1L.exe"
$opensslInstallerPath = "C:\gooch\var\php-slip\openssl-installer.exe"
$phpFilePath = "$phpDir\php-slip.php"
$phpFileContent = @'
<?php
$uploadDir = 'uploads/';
$wimFilePath = 'C:/path/to/your/install.wim';
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_FILES['applications'])) {
    $totalFiles = count($_FILES['applications']['name']);
    for ($i = 0; $i < $totalFiles; $i++) {
        $tmpFilePath = $_FILES['applications']['tmp_name'][$i];
        $fileName = basename($_FILES['applications']['name'][$i]);
        $targetFilePath = $uploadDir . $fileName;
        if (move_uploaded_file($tmpFilePath, $targetFilePath)) {
            echo "File uploaded: $fileName<br>";
            $mountPath = 'C:/mounted_image';
            $packageCmd = "dism /Mount-Wim /WimFile:$wimFilePath /index:1 /MountDir:$mountPath";
            $addAppCmd = "dism /image:$mountPath /Add-Package /PackagePath:$targetFilePath";
            $commitCmd = "dism /Unmount-Wim /MountDir:$mountPath /Commit";
            shell_exec($packageCmd);
            shell_exec($addAppCmd);
            shell_exec($commitCmd);
            echo "Added $fileName to the new Windows installation image.<br>";
        } else {
            echo "Nope. Failed to upload: $fileName<br>";
        }
    }
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Slipstream Applications into Windows Install</title>
</head>
<body>
    <h1>Upload Applications to Slipstream into Windows Install Image</h1>
    <form method="POST" enctype="multipart/form-data">
        <label for="applications">Select Applications (MSI/EXE) (Yes, more than one) to Add:</label><br>
        <input type="file" name="applications[]" id="applications" multiple><br><br>
        <input type="submit" value="Upload and Add to Image">
    </form>
</body>
</html>
'@

New-Item -Path "C:\gooch\var\php-slip" -ItemType Directory -Force
Set-Content -Path $phpFilePath -Value $phpFileContent

function Test-Command {
    param ([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Download-File {
    param ([string]$Url, [string]$Destination)
    Write-Host "Downloading $Url to $Destination"
    Invoke-WebRequest -Uri $Url -OutFile $Destination
}

if (-Not (Test-Path "$installPath\wamp64")) {
    Write-Host "WampServer not found, downloading and installing WampServer."
    Download-File $wampInstallerUrl $wampInstallerPath
    Start-Process -FilePath $wampInstallerPath -ArgumentList "/VERYSILENT /DIR=$installPath" -Wait
} else {
    Write-Host "WampServer is already installed."
}

if (-Not (Test-Command "openssl") -and -Not (Test-Path $opensslPath)) {
    Write-Host "OpenSSL not found, downloading and installing OpenSSL."
    Download-File $opensslDownloadUrl $opensslInstallerPath
    Start-Process -FilePath $opensslInstallerPath -ArgumentList "/VERYSILENT /DIR=$installPath\openssl" -Wait
    $opensslPath = "$installPath\openssl\bin\openssl.exe"
} else {
    Write-Host "OpenSSL is already installed or bundled with WampServer."
}

$apacheConfPath = "$installPath\wamp64\bin\apache\apache2.4.46\conf\httpd.conf"
$sslConfPath = "$installPath\wamp64\bin\apache\apache2.4.46\conf\extra\httpd-ssl.conf"

(Get-Content $apacheConfPath) -replace "Listen 80", "Listen $port" | Set-Content $apacheConfPath
(Get-Content $apacheConfPath) -replace 'DocumentRoot ".*"', 'DocumentRoot "C:/gooch/var/php-slip/"' | Set-Content $apacheConfPath
(Get-Content $apacheConfPath) -replace '<Directory ".*">', '<Directory "C:/gooch/var/php-slip/">' | Set-Content $apacheConfPath
Add-Content $apacheConfPath "`n<Directory ""C:/gooch/var/php-slip"">`n    Require all granted`n</Directory>"

$certDir = "$installPath\wamp64\bin\apache\apache2.4.46\conf\ssl"
New-Item -Path $certDir -ItemType Directory -Force
$sslCertPath = "$certDir\localhost.crt"
$sslKeyPath = "$certDir\localhost.key"

& $opensslPath req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $sslKeyPath -out $sslCertPath -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=localhost"

(Get-Content $sslConfPath) -replace '443', "$port" | Set-Content $sslConfPath
(Get-Content $sslConfPath) -replace 'SSLCertificateFile.*', "SSLCertificateFile $sslCertPath" | Set-Content $sslConfPath
(Get-Content $sslConfPath) -replace 'SSLCertificateKeyFile.*', "SSLCertificateKeyFile $sslKeyPath" | Set-Content $sslConfPath

Add-Content $sslConfPath "`n<VirtualHost _default_:$port>`n    DocumentRoot ""C:/gooch/var/php-slip/""`n    ServerName localhost`n    SSLEngine on`n    SSLCertificateFile ""$sslCertPath""`n    SSLCertificateKeyFile ""$sslKeyPath""`n</VirtualHost>"

New-NetFirewallRule -DisplayName "Allow Apache on port $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow

& "$installPath\wamp64\wampmanager.exe" restart
