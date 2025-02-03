# Change Log
All notable changes to this project will be documented in this file.
 
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
 
## [Unreleased] - 2025-02-02
 
Update and correct script
 
### Added
Script manage_ipv6.sh to enable or disable IPv6
Function copy_file.sh to handle file copy with compare and confirmation, enable chmod +x on sh file
Function update_file.sh to handle update config file if necessary
 
### Changed
systemd.sh v1.0.1 
-removed duplicate function
-remove_systemd_service can call ExecStart script with with param given by -env arg to clean service

usb_toolbox.sh v1.0.7
-clean script
-change -is to -si, -rs to -sr
-remove example
-add arg -error to display error code

wifi_hotspot.sh v1.0.1
refactoring all script
 
### Fixed
systemd.sh v1.0.1 correct remove_systemd_service calling to handle other arguments

usb_toolbox.sh v1.0.7 
-correct remove_systemd_service
-if the installation of systemd was requested, no longer mounts the volume

### Removed
none