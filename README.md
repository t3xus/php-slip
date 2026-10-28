# php-slip

![Static Badge](https://img.shields.io/badge/Author-Jgooch-1F4D37)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Target](https://img.shields.io/badge/Target-Microsoft%20Windows%2011-357EC7)

Tools for silent installation of WampServer and OpenSSL, plus configuration for deploying a simple PHP application on Windows.

## What the scripts do

- Install WampServer and OpenSSL if they are not already present
- Configure Apache to serve from `C:\gooch\var\php-slip`
- Listen on port 8778 with local HTTPS
- Add a firewall rule for port 8778
- Provide a basic `slip.php` entry point

## Files

- `php-slip.ps1` — main setup script
- `silent-wamp.ps1` — silent WampServer installer helper
- `slip.php` — sample PHP entry point

## Usage

Run the PowerShell scripts as Administrator.

## License

MIT License
