# Change Log
All notable changes to this project will be documented in this file.
 
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2025-06-28
 
Update and correct scripts
 
### Added
Script Linux
-rsync_backup.sh command rsync application
-ssh-copy-id.sh  check ssh key, create ssh key, check distant home folder, check host config, send public key to distant server, check connection with public key
-functions\pid.sh create pid file and checkit

Script Windows
-install_protocol_callto.cmd v1.0 add protocol callto:\\ to windows
-install_protocol_rdp.com v1.5 add protocol rdp:\\ to windows and a wrapper to mstsc.exe
-patch_rdp.ps1 v1.3 patch termserv.dll to handle multiple connection
-robocopy_vss.cmd v1.1 use vss with robocopy
-cleanuserfolders v1.1 clean

### Changed
Script Linux
-systemd.sh v1.0.4 add restart value
-rsync_backup.sh v1.0.4 check if wifi is blocked by software or hardware
-checker.sh v1.0.2 add bool type, functions check_user_read_from_files,
-network.sh v1.0.1 add function check_wifi_block
 
### Fixed
Script Linux
-systemd.sh v1.0.4 correct $0 with $script_name, correct execstart value
-usb_toolbox.sh v1.0.9 correct $0 with $script_name, correct mount with mount_point param
-rsync_backup.sh v1.0.4 correct $0 with $script_name
-checker.sh v1.0.2 correct function check_user_write_to_file
-copy_file v1.0.4 correct function copy_file to determine if copying file or folder, correct function copy_dependencies

### Removed
none

## [Unreleased] - 2025-02-09
 
Update and correct scripts
 
### Added
Script crontab.sh to Help cronjob creation
 
### Changed
systemd.sh v1.0.2 add error infos
wifi_hotspot.sh v1.0.2 add error infos
copy_file.sh v1.0.1 when file exist can keep both file with increment new file
 
### Fixed
copy_file.sh v1.0.1
-fixed file/directory destination without extension and considering /path/to/file/ as folder and /path/to/file as file
correct displaying replace file with info when calling from external script

### Removed
none

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
