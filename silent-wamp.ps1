#paths
$wampInstallerUrl = "https://sourceforge.net/projects/wampserver/files/WampServer%203/Wampserver%203.2.6/wampserver3.2.6_x64.exe/download"
$wampInstallerPath = "C:\gooch\var\php-slip\wampserver-installer.exe"
$installPath = "C:\gooch\var\php-slip"
$phpDir = "C:\gooch\var\php-slip"
$port = 8778
$opensslPath = "$installPath\wamp64\bin\apache\apache2.4.46\bin\openssl.exe"
$opensslDownloadUrl = "https://slproweb.com/download/Win64OpenSSL-1_1_1L.exe"
$opensslInstallerPath = "C:\gooch\var\php-slip\openssl-installer.exe"

#make0more paths
New-Item -Path "C:\gooch\var\php-slip" -ItemType Directory -Force

#are you real
function Test-Command {
    param (
        [string]$Command
    )
    $errorActionPreference = 'SilentlyContinue'
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $? # returns true if command exists, false otherwise
}

#get the file
function Download-File {
    param (
        [string]$Url,
        [string]$Destination
    )
    Write-Host "Downloading $Url to $Destination"
    Invoke-WebRequest -Uri $Url -OutFile $Destination
}

# no talking fetch and install WampServer 
if (-Not (Test-Path "$installPath\wamp64")) {
    Write-Host "WampServer not found, downloading and installing WampServer."
    Download-File $wampInstallerUrl $wampInstallerPath
    Start-Process -FilePath $wampInstallerPath -ArgumentList "/VERYSILENT /DIR=$installPath" -Wait
} else {
    Write-Host "WampServer is already installed."
}

# OpenSSL is installed?
if (-Not (Test-Command "openssl") -and -Not (Test-Path $opensslPath)) {
    Write-Host "OpenSSL not found, downloading and installing OpenSSL."
    Download-File $opensslDownloadUrl $opensslInstallerPath
    Start-Process -FilePath $opensslInstallerPath -ArgumentList "/VERYSILENT /DIR=$installPath\openssl" -Wait
    $opensslPath = "$installPath\openssl\bin\openssl.exe" # Set the new OpenSSL path
} else {
    Write-Host "OpenSSL is already installed or bundled with WampServer."
}

#listen 8778 serve C:\gooch\var\php-slip\
$apacheConfPath = "$installPath\wamp64\bin\apache\apache2.4.46\conf\httpd.conf"
$sslConfPath = "$installPath\wamp64\bin\apache\apache2.4.46\conf\extra\httpd-ssl.conf"

(Get-Content $apacheConfPath) -replace "Listen 80", "Listen $port" |
    Set-Content $apacheConfPath

# paths and paths and paths
(Get-Content $apacheConfPath) -replace 'DocumentRoot ".*"', 'DocumentRoot "C:/gooch/var/php-slip/"' |
    Set-Content $apacheConfPath
(Get-Content $apacheConfPath) -replace '<Directory ".*">', '<Directory "C:/gooch/var/php-slip/">' |
    Set-Content $apacheConfPath

# welcome all
Add-Content $apacheConfPath "`n<Directory ""C:/gooch/var/php-slip"">`n    Require all granted`n</Directory>"

# local cert for https://computer0name
$certDir = "$installPath\wamp64\bin\apache\apache2.4.46\conf\ssl"
New-Item -Path $certDir -ItemType Directory -Force

$sslCertPath = "$certDir\localhost.crt"
$sslKeyPath = "$certDir\localhost.key"
& $opensslPath req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $sslKeyPath -out $sslCertPath -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=localhost"

(Get-Content $sslConfPath) -replace '443', "$port" |
    Set-Content $sslConfPath

(Get-Content $sslConfPath) -replace 'SSLCertificateFile.*', "SSLCertificateFile $sslCertPath" |
    Set-Content $sslConfPath
(Get-Content $sslConfPath) -replace 'SSLCertificateKeyFile.*', "SSLCertificateKeyFile $sslKeyPath" |
    Set-Content $sslConfPath

Add-Content $sslConfPath "`n<VirtualHost _default_:$port>`n    DocumentRoot ""C:/gooch/var/php-slip/""`n    ServerName localhost`n    SSLEngine on`n    SSLCertificateFile ""$sslCertPath""`n    SSLCertificateKeyFile ""$sslKeyPath""`n</VirtualHost>"

# 8778 on Windows Firewall
New-NetFirewallRule -DisplayName "Allow Apache on port $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow

# Restart 
& "$installPath\wamp64\wampmanager.exe" restart
