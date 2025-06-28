#!/bin/bash
# -------------------------------------------------------------------
# Error Codes and their Meanings
# Version: 1.0.2
# Author: Torayld
# -------------------------------------------------------------------

ERROR_OK=0              # OK

ERROR_INVALID_OPTION=10  # Invalid or unknown option provided
ERROR_MISSING_ARGUMENT=11  # Missing argument for a required option
ERROR_OPTION_CONFLICT=12  # Conflict between 2 arguments
ERROR_ARGUMENT_WRONG=13  # Argument value is not valid

ERROR_INVALID_FILE=20    # The file does not exist or is not valid
ERROR_NOT_EXECUTABLE=21   # The file is not executable
ERROR_FILE_COPY_FAILED=22 # The file copy operation failed
ERROR_PERMISSION_FAILED=23 # The chmod operation failed
ERROR_COPY_CANCELED=24 # The file copy operation canceled

ERROR_FAILED_TO_RESET_INTERFACE=30  # Failed to reset the interface

ERROR_MOUNT_FAILED=40    # The mount operation failed
ERROR_MOUNT_MOUNTED_DIFFERENT=41 # The disk is mounted but on a different mount point
ERROR_DISK_NOT_FOUND=42   # The disk was not found
ERROR_FSTAB_UPDATE=43 # Unable to update fstab

ERROR_INSTALL_FAILED=50  # The installation failed
ERROR_UNINSTALL_FAILED=51  # The uninstallation failed

ERROR_SERVICE_START_FAILED=60 # The service failed to start
ERROR_SERVICE_FILE_CREATION_FAILED=61 # The systemd service file creation failed
ERROR_SERVICE_RELOAD_FAILED=61 # Failed to reload service
ERROR_SERVICE_REMOVE_FAILED=62 # Failed to remove systemd service
ERROR_SERVICE_INVALID_DOC_TAG=63 # The service file does not contain "autoscript" in the Documentation tag
ERROR_SERVICE_SCRIPT_REMOVE_FAILED=64 # Unable to remove the script file
ERROR_SERVICE_FILE_NOT_FOUND=65 # The service file does not exist
ERROR_SERVICE_FILE_REMOVE_FAILED=65 # Unable to remove the service file

ERROR_RSYNC_FAILED=70 # Rsync operation failed

ERROR_WLAN_NOT_FOUND=80 # The WLAN interface was not found
ERROR_WLAN_HARDWARE_DISABLED=81 # The WLAN hardware is disabled
ERROR_WLAN_SOFT_DISABLED=82 # The WLAN software is disabled

# Display error codes
display_error_codes() {
    echo "Error Codes and their Meanings:"
    echo "---------------------------------------------------"
    echo " $ERROR_INVALID_OPTION   : Invalid or unknown option provided."
    echo " $ERROR_MISSING_ARGUMENT   : Missing argument for a required option."
    echo " $ERROR_OPTION_CONFLICT   : Conflict between 2 arguments."
    echo " $ERROR_ARGUMENT_WRONG   : Argument value is not valid."
    echo " $ERROR_INVALID_FILE   : The file does not exist or is not valid."
    echo " $ERROR_NOT_EXECUTABLE   : The file is not executable."
    echo " $ERROR_FILE_COPY_FAILED   : The file copy operation failed."
    echo " $ERROR_PERMISSION_FAILED   : The chmod operation failed."
    echo " $ERROR_COPY_CANCELED   : The file copy operation canceled."
    echo " $ERROR_FAILED_TO_RESET_INTERFACE   : Failed to reset the interface."
    echo " $ERROR_MOUNT_FAILED   : The mount operation failed."
    echo " $ERROR_MOUNT_MOUNTED_DIFFERENT   : The disk is mounted but on a different mount point."
    echo " $ERROR_DISK_NOT_FOUND   : The disk was not found."
    echo " $ERROR_UMOUNT_FAILED   : The umount operation failed."
    echo " $ERROR_UMOUNT_DIRECTORY_FAILED   : The umount directory removal failed."
    echo " $ERROR_FSTAB_UPDATE   : Unable to update fstab."
    echo " $ERROR_INSTALL_FAILED   : The installation failed."
    echo " $ERROR_UNINSTALL_FAILED   : The uninstallation failed."
    echo " $ERROR_SERVICE_START_FAILED   : The service failed to start."
    echo " $ERROR_MISSING_ARGUMENT   : Missing argument for a required option."
    echo " $ERROR_SERVICE_FILE_CREATION_FAILED   : The systemd service file creation failed."
    echo " $ERROR_SERVICE_RELOAD_FAILED   : Failed to reload service."
    echo " $ERROR_SERVICE_REMOVE_FAILED   : Failed to remove systemd service."
    echo " $ERROR_SERVICE_INVALID_DOC_TAG   : The service file does not contain \"autoscript\" in the Documentation tag."
    echo " $ERROR_SERVICE_SCRIPT_REMOVE_FAILED   : Unable to remove the script file."
    echo " $ERROR_SERVICE_FILE_NOT_FOUND   : The service file does not exist."
    echo " $ERROR_SERVICE_FILE_REMOVE_FAILED   : Unable to remove the service file."
    echo " $ERROR_RSYNC_FAILED   : Rsync operation failed."
    echo " $ERROR_WLAN_NOT_FOUND   : The WLAN interface was not found."
    echo " $ERROR_WLAN_HARDWARE_DISABLED   : The WLAN hardware is disabled."
    echo " $ERROR_WLAN_SOFT_DISABLED   : The WLAN software is disabled."
    echo "---------------------------------------------------"
}