#!/bin/bash
# -------------------------------------------------------------------
# USB Drive Toolbox
# Version: 1.0.7
# Author: Torayld
# -------------------------------------------------------------------

# Variables globales
SCRIPT_VERSION="v1.0.7"

# Default parameters
label=""                # Default label of the USB device
partuuid=""             # Default PARTUUID of the partition
mount_point="/mnt/usb"  # Default mount point
install_hdparm=false    # Trigger to uninstall hdparm if installed by script
selected_partition=""
install_systemd=''      # Default to not install into systemd
uninstall_systemd=false # Default to not uninstall from systemd
add_fstab=false         # Default to not adding to fstab
remove_fstab=false      # Default to not removing from fstab

fstap_allready=false    # Flag to check if the partition is already in /etc/fstab

# Print version information
print_version() {
    echo "$0 version $SCRIPT_VERSION"
    exit $ERROR_OK
}

# Function to display help information
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -m, --mount <path>               Specify the mount point (default: /mnt/usb)"
    echo "  -u, --umount <path>              Umount the partition and remove the mount point"
    echo "  -p, --partuuid <partuuid>        Specify the PARTUUID of the partition"
    echo "  -s, --sd <partition>             Specify the partition directly (avoid auto-detection)"
    echo "  -f, --fstab                      Add the partition to /etc/fstab for automatic mounting"
    echo "  -rf, --remove-fstab              Remove the partition from /etc/fstab for automatic mounting"
    echo "  -si, --systemd-install <param>   Install as a systemd service with a parameter passed to the child script"
    echo "  -sr, --systemd-remove            Remove the systemd service ONLY and exit"
    echo "  -v, --version                    Display the script version"
    echo "  -er, --error                     Display error codes and their meanings."
    echo "  -h, --help                       Display this help message"
    echo
    echo "Priority of parameters:"
    echo "  1. --partuuid <partuuid>: First, the script will attempt to use PARTUUID to identify the partition."
    echo "  2. --sd <partition>: If no PARTUUID is provided, the script will then use the partition identifier (e.g., /dev/sda1)."
    echo "  3. --label <label>: If neither PARTUUID nor partition identifier is provided, the script will search for a partition with the specified label."
    echo "  4. If none of the above is provided, the script will search for the last connected USB disk."
}

# Error codes (documenting the exit codes)
ERROR_OK=0              # OK
ERROR_INVALID_OPTION=10  # Invalid or unknown option provided
ERROR_MISSING_ARGUMENT=11  # Missing argument for a required option
ERROR_OPTION_CONFLICT=12  # Conflict between 2 arguments
ERROR_INVALID_FILE=20    # The file does not exist or is not valid
ERROR_NOT_EXECUTABLE=21   # The file is not executable
ERROR_FILE_COPY_FAILED=22 # The file copy operation failed
ERROR_PERMISSION_FAILED=23 # The chmod operation failed
ERROR_INSTALL_FAILED=24  # The installation failed
ERROR_UNINSTALL_FAILED=25  # The uninstallation failed
ERROR_MOUNT_FAILED=30    # The mount operation failed
ERROR_MOUNT_MOUNTED_DIFFERENT=31 # The disk is mounted but on a different mount point
ERROR_DISK_NOT_FOUND=32   # The disk was not found
ERROR_UMOUNT_FAILED=40    # The umount operation failed
ERROR_UMOUNT_DIRECTORY_FAILED=41 # The umount directory removal failed
ERROR_FSTAB_UPDATE=50 # Unable to update fstab
ERROR_SERVICE_FILE_CREATION_FAILED=61 # The systemd service file creation failed
ERROR_SERVICE_REMOVE_FAILED=70 # Failed to remove systemd service


# Display error codes
display_error_codes() {
    echo "Error Codes and their Meanings:"
    echo "---------------------------------------------------"
    echo " $ERROR_INVALID_OPTION    : Invalid or unknown option provided."
    echo " $ERROR_MISSING_ARGUMENT  : Missing argument for a required option."
    echo " $ERROR_OPTION_CONFLICT   : Conflict between 2 arguments."
    echo " $ERROR_INVALID_FILE      : The file does not exist or is not valid."
    echo " $ERROR_NOT_EXECUTABLE    : The file is not executable."
    echo " $ERROR_FILE_COPY_FAILED  : The file copy operation failed."
    echo " $ERROR_PERMISSION_FAILED : The chmod operation failed."
    echo " $ERROR_INSTALL_FAILED    : The installation failed."
    echo " $ERROR_UNINSTALL_FAILED  : The uninstallation failed."
    echo " $ERROR_MOUNT_FAILED      : The mount operation failed."
    echo " $ERROR_MOUNT_MOUNTED_DIFFERENT : The disk is mounted but on a different mount point."
    echo " $ERROR_DISK_NOT_FOUND     : The disk was not found."
    echo " $ERROR_UMOUNT_FAILED     : The umount operation failed."
    echo " $ERROR_UMOUNT_DIRECTORY_FAILED : The umount directory removal failed."
    echo " $ERROR_FSTAB_UPDATE      : Unable to update fstab."
    echo " $ERROR_SERVICE_FILE_CREATION_FAILED : The systemd service file creation failed."
    echo " $ERROR_SERVICE_REMOVE_FAILED : Failed to remove systemd service."
    echo "---------------------------------------------------"
}

# Function to check if the partition is already in /etc/fstab
check_fstab() {
    # Check if the PARTUUID is already in /etc/fstab
    if grep -q "$partuuid" /etc/fstab || grep -q "$label" /etc/fstab; then
        fstap_allready=true
    fi
}

# Function to install the systemd service
install_systemd_service() {
    if [ ! -f "./systemd.sh" ]; then
        echo "Error: systemd.sh not found to install service."
        exit $ERROR_INVALID_FILE
    fi

    echo "Installing systemd service with parameter..."

    param=""
    if [[ -n "$install_systemd" && "$install_systemd" != "true" ]]; then
        param=$install_systemd
    fi

    # Calling systemd.sh to install the service
    output=$(./systemd.sh -exe "$0" -cs -csf -n "usb_mount" -env "PARTUUID='$partuuid' MOUNT_POINT='$mount_point'" \
        -d "Mounting USB Drive with Systemd" $param)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "Systemd service installed successfully."
        exit $ERROR_OK
    else
        echo "Error installing systemd service: $output"
        exit $exit_code
    fi
}


# Function to remove the systemd service
remove_systemd_service() {

    # Search for the MOUNT_POINT value in /etc/systemd/system/usb_mountX.service files
    result=$(grep -rl "MOUNT_POINT='$mount_point'" /etc/systemd/system/usb_mount*.service)
    if [ -n "$result" ]; then
        echo "Found MOUNT_POINT=$mount_point in the following service file(s):"
        echo "$result"
    else
        echo "No service files found with MOUNT_POINT=$mount_point."
        exit $ERROR_INVALID_FILE
    fi

    # Check if the service file exists
    if [ ! -f "./systemd.sh" ]; then
        echo "Error: systemd.sh not found to remove service."
        exit $ERROR_INVALID_FILE
    fi

    # Call the child script to remove the service
    output=$(./systemd.sh -rm $result -env "-u $mount_point")
    exit_code=${PIPESTATUS[0]} #Capture exit code

    # Check the exit status of the child script
    if [ $exit_code -eq 0 ]; then
        echo "Systemd service was removed."
        exit $ERROR_OK
    else
        echo "systemd.sh encountered an error : "$output
        exit $exit_code
    fi
}

# Function to add the partition to /etc/fstab
add_to_fstab() {
    echo "Adding the partition to /etc/fstab for automatic mounting..."
    
    # Check if the entry is already present in fstab
    check_fstab
    if [ "$fstap_allready" = true ]; then
        echo "The partition is already listed in /etc/fstab."
    else
        # Add the fstab entry using PARTUUID
        echo "PARTUUID=$partuuid $mount_point $filesystem defaults 0 2" | sudo tee -a /etc/fstab
        if [ $? -ne 0 ]; then
            echo "Error: Unable to modify /etc/fstab."
            exit $ERROR_FSTAB_UPDATE
        fi
        echo "The partition has been added to /etc/fstab."
    fi
}

# Function to remove the partition from /etc/fstab
remove_from_fstab() {
    # Check if $partuuid is empty
    if [ -z "$partuuid" ]; then
        echo "Error: PARTUUID is empty. Cannot remove from /etc/fstab."
        exit $ERROR_MISSING_ARGUMENT
    fi
    
    echo "Removing the partition from /etc/fstab for automatic mounting..."

    # Check if the entry exists in fstab
    if grep -q "$partuuid" /etc/fstab; then
        sudo sed -i "/$partuuid/d" /etc/fstab
        if [ $? -ne 0 ]; then
            echo "Error: Unable to modify /etc/fstab."
            exit $ERROR_FSTAB_UPDATE
        fi
        echo "The partition has been removed from /etc/fstab."
    else
        echo "No entry found in /etc/fstab for this partition."
    fi
}

# Function to remove the systemd service
mount_partition_func() {
    # Create the mount point if it doesn't exist
    if [ ! -d "$mount_point" ]; then
        sudo mkdir -p "$mount_point"
        echo "Created mount point: $mount_point"
    fi

    # Check if the device is already mounted
    if mount | grep -q "$selected_partition"; then
        # Check if the actual mount point matches
        partition_name=$(basename "$selected_partition")
        actual_mount_point=$(lsblk -o NAME,MOUNTPOINT | grep "$partition_name" | awk '{print $2}')
        echo "The partition $selected_partition is already mounted on $actual_mount_point."

        if [ "$actual_mount_point" != "$mount_point" ]; then
            echo "but not on the expected mount point ($mount_point)."
            exit $ERROR_MOUNT_MOUNTED_DIFFERENT
        fi
    else
        echo "The disk $selected_partition is not mounted. Mounting now..."
        sudo mount $selected_partition $mount_point
        if [ $? -eq 0 ]; then
            echo "The disk $selected_partition was successfully mounted at $mount_point."
        else
            echo "Error while mounting $selected_partition ($?)."
            exit $ERROR_MOUNT_FAILED
        fi
    fi
}

# Function to unmount the partition and remove the mount point directory if it's empty
umount_partition_func() {
    # Ensure that the argument provided with -u is not empty
    if [ -z "$umount_target" ]; then
        echo "Error: You must specify a partition or mount point with the -u option."
        exit $ERROR_MISSING_ARGUMENT
    fi
    
    echo "Unmounting $umount_target..."

    # Determine a mount point if sdaX is provided
    if [[ ! "$umount_target" == /* ]]; then
        # If it's a partition, find the corresponding mount point using mount command
        mount_point=$(mount | grep "$umount_target" | awk '{print $3}')
        if [ -z "$mount_point" ]; then
            echo "Error: $umount_target is not mounted."
            exit $ERROR_OK   # Exit with OK status as the partition is not mounted
        else
            echo "Partition $umount_target is mounted at $mount_point."
        fi
    else
        # If it's a mount point, use it directly
        mount_point="$umount_target"
    fi

    # Now unmount the target (either partition or mount point)
    if mount | grep -q "$mount_point"; then
        sudo umount "$mount_point"
        if [ $? -eq 0 ]; then
            echo "$mount_point has been successfully unmounted."
            
            # If the mount point is empty, remove the directory
            if [ -d "$mount_point" ] && [ ! "$(ls -A $mount_point)" ]; then
                sudo rmdir "$mount_point"
                if [ $? -eq 0 ]; then
                    echo "The mount point directory $mount_point has been removed."
                else
                    echo "Error while removing directory $mount_point."
                    exit $ERROR_UMOUNT_DIRECTORY_FAILED
                fi
            fi
        else
            echo "Error while unmounting $mount_point."
            echo $(lsof | grep $mount_point)
            exit $ERROR_UMOUNT_FAILED
        fi
    else
        echo "$mount_point is not mounted."
        exit ERRORK
    fi
}

get_label_from_partition() {
    # Get the label of the partition
    label=$(blkid "$selected_partition" | grep -oP ' LABEL="\K[^"]+')
}

get_partuuid_from_partition() {
    # Get the label of the partition
    partuuid=$(blkid "$selected_partition" | grep -oP 'PARTUUID="\K[^"]+')
}

find_usb_drive() {
    # Get the last USB disk from dmesg using the desired string and remove square brackets
    device_name=$(dmesg | grep -oP 'sd \S+: \[\S+\] Attached SCSI disk' | tail -n 1 | awk '{print "/dev/" $3}' | sed 's/\[//g' | sed 's/\]//g')

    # If the disk is partitioned, find the largest partition
    if [ -n "$device_name" ]; then
        echo "List of partitions of $device_name:"
        lsblk -o NAME,SIZE,TYPE $device_name

        # Extract partitions (ignore "disk" type and the header) and sort by size
        partitions=$(lsblk -o NAME,SIZE,TYPE $device_name | grep -v "disk" | grep -v "NAME" | sort -k2 -h)

        # Clean up tree characters (e.g.,├─, └─ or |-, `- in systemctl) and retrieve only the partition name
        clean_partitions=$(echo "$partitions" | sed 's/^[[:space:]]*└─//g' | sed 's/^[[:space:]]*├─//g' | sed 's/^[[:space:]]*`-//g' | sed 's/^[[:space:]]*|-//g')

        # Select the largest partition (the last one after sorting) and prepend /dev/
        selected_partition="/dev/$(echo "$clean_partitions" | tail -n 1 | awk '{print $1}')"
        
        # Now, use blkid to find LABEL and PARTUUID of the device
        get_partuuid_from_partition
        get_label_from_partition
    fi
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            print_version
            exit $ERROR_OK
            ;;
        -er|--error)
            display_error_codes
            exit $ERROR_OK
            ;;
        -h|--help)
            display_help
            exit $ERROR_OK
            ;;
        -si=*|--systemd-install=*)
            # Extraire la valeur après le "="
            install_systemd="${1#*=}"
            shift
            ;;
        -si|--systemd-install)
            if [[ -n "$2" && "$2" != -* ]]; then
                install_systemd="$2"
                shift 2
            else
                install_systemd=true
                shift
            fi
            ;;
        -sr|--systemd-remove)
            uninstall_systemd=true
            shift
            ;;
        -m|--mount)
            if [[ "$2" =~ ^\".*\"$ ]]; then
                mount_point=$(echo "$2" | sed 's/^"//' | sed 's/"$//')
                shift 2
            elif [ -n "$2" ] && [[ "$2" != -* ]]; then
                mount_point="$2"
                shift 2
            else
                echo "Error: --mount requires a parameter."
                exit $ERROR_MISSING_ARGUMENT
            fi
            ;;
        -u|--umount)
            if [[ "$2" =~ ^\".*\"$ ]]; then
                umount_target=$(echo "$2" | sed 's/^"//' | sed 's/"$//')
                shift 2
            elif [ -n "$2" ] && [[ "$2" != -* ]]; then
                umount_target="$2"
                shift 2
            else
                echo "Error: --mount requires a parameter."
                exit $ERROR_MISSING_ARGUMENT
            fi
            ;;
        -p|--partuuid)
            if [[ "$2" =~ ^\".*\"$ ]]; then
                partuuid=$(echo "$2" | sed 's/^"//' | sed 's/"$//')
                shift 2
            elif [ -n "$2" ] && [[ "$2" != -* ]]; then
                partuuid="$2"
                shift 2
            else
                echo "Error: --partuuid requires a parameter."
                exit $ERROR_MISSING_ARGUMENT
            fi
            ;;
        -s|--sd)
            if [[ "$2" =~ ^\".*\"$ ]]; then
                selected_partition=$(echo "$2" | sed 's/^"//' | sed 's/"$//')
                shift 2
            elif [ -n "$2" ] && [[ "$2" != -* ]]; then
                selected_partition="$2"
                shift 2
            else
                echo "Error: --sd requires a parameter."
                exit $ERROR_MISSING_ARGUMENT
            fi
            ;;
        -f|--fstab)
            add_fstab=true
            shift
            ;;
        -rf|--remove-fstab)
            remove_fstab=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            display_help
            exit $ERROR_INVALID_OPTION
            ;;
    esac
done

# If the -u or --umount option is used, unmount the partition
if [ -n "$umount_target" ]; then
    umount_partition_func
    exit $ERROR_OK
fi

# Check if -f and -i are used together
if [ "$uninstall_systemd" = true ] && [ "$remove_fstab" = true ]; then
    echo "Error: You cannot use both -u (uninstall systemd service) and -rf (remove fstab) at the same time."
    exit $ERROR_OPTION_CONFLICT
fi

# If the -rs option is used, remove the systemd service
if [ "$uninstall_systemd" = true ]; then
    remove_systemd_service
    exit $ERROR_OK
fi

# Check if -f and -i are used together
if [ -n "$install_systemd" ] && [ "$add_fstab" = true ]; then
    echo "Error: You cannot use both -i (install systemd service) and -f (add to fstab) at the same time."
    exit $ERROR_OPTION_CONFLICT
fi

# Check if running from systemd and import environment variables
if [ -n "$INVOCATION_ID" ]; then
    systemctl --user import-environment LABEL PARTUUID SELECTED_PARTITION MOUNT_POINT
    echo "Starting from SystemCTL import environment variable ${LABEL} ${PARTUUID} ${SELECTED_PARTITION} ${MOUNT_POINT}" | sudo tee /dev/kmsg
fi

# Use systemd passed environment variables if available
if [ -n "${LABEL}" ]; then
    label="${LABEL}"
fi
if [ -n "${PARTUUID}" ]; then
    partuuid="${PARTUUID}"
fi
if [ -n "${SELECTED_PARTITION}" ]; then
    selected_partition="${SELECTED_PARTITION}"
fi
if [ -n "${MOUNT_POINT}" ]; then
    mount_point="${MOUNT_POINT}"
fi

# Find the partition using partuuid, label, or sda
echo "Finding partition with provided identifiers..."

# Search by partuuid first
if [ -n "$partuuid" ]; then
    selected_partition=$(blkid | grep "PARTUUID=\"$partuuid\"" | awk '{print $1}' | sed 's/://')
    echo "The selected partition with PARTUUID is: $selected_partition"
    # If partuuid is found, find label
    if [ -n "$selected_partition" ]; then
        get_label_from_partition
    fi
fi

# If no partuuid, try label
if [ -z "$selected_partition" ] && [ -n "$label" ]; then
    selected_partition=$(blkid | grep "LABEL=\"$label\"" | awk '{print $1}' | sed 's/://')
    echo "The selected partition with LABEL is: $selected_partition"
    # If label is found, find partuuid
    if [ -n "$selected_partition" ]; then
        get_partuuid_from_partition
    fi
fi

# If no partuuid or label, try sda
if [ -n "$selected_partition" ]; then
    echo "The givent partition with param SD is: $selected_partition"
    
    # Check if the partition starts with "/dev/"
    if [[ ! "$selected_partition" =~ ^/dev/ ]]; then
        # If not, prepend "/dev/" to the partition name
        selected_partition="/dev/$selected_partition"
    fi
    get_label_from_partition
    get_partuuid_from_partition
fi

# If still no partition found, take the last USB disk found in dmesg
if [ -z "$selected_partition" ]; then
    echo "No partition found for the provided identifiers. Taking the last USB disk found in dmesg..."

   find_usb_drive
fi

if [ -z "$selected_partition" ]; then
    echo "No partition found."
    exit $ERROR_DISK_NOT_FOUND
fi

# Display the selected partition
echo "The selected partition is: $selected_partition"
echo "The Label is: $label"
echo "The PARTUUID is: $partuuid"

# If the -rf option is used, remove the entry from fstab
if [ "$remove_fstab" = true ]; then
    remove_from_fstab
    exit $ERROR_OK
fi

# If the -si option is used, install the systemd service
if [ -n "$install_systemd" ]; then
    install_systemd_service
fi

# Retrieve and display the filesystem of the selected partition
filesystem=$(sudo blkid $selected_partition | awk -F ' ' '{for(i=1;i<=NF;i++) if($i ~ /TYPE=/) print $i}' | cut -d '=' -f 2)

# Display the filesystem format
echo "Filesystem of $selected_partition: $filesystem"

# Check if the filesystem is compatible with TRIM (ext4, f2fs, btrfs)
if [[ "$filesystem" == "ext4" || "$filesystem" == "f2fs" || "$filesystem" == "btrfs" ]]; then
  echo "The filesystem is compatible with TRIM."

  # Check if the device is an SSD
  rota=$(lsblk -d -o ROTA $selected_partition | tail -n 1)
  if [ "$rota" -eq 0 ]; then
    echo "The disk is an SSD."
    
    # Install hdparm before checking TRIM support if necessary
    if ! command -v hdparm &> /dev/null; then
      echo "hdparm is not installed. Installing..."
      sudo apt-get update -y
      sudo apt-get install -y hdparm
      if [ $? -ne 0 ]; then
        echo "Error: Unable to install hdparm."
        exit $ERROR_INSTALL_FAILED
      fi
      install_hdparm=true  # Set install_hdparm to true when installing hdparm
    fi

    # Check if the device supports TRIM
    if sudo hdparm -I $selected_partition | grep -q "TRIM supported"; then
      echo "The device supports TRIM."
    else
      echo "The device does not support TRIM."
    fi

    # Uninstall hdparm after checking
    if [ "$install_hdparm" = true ]; then
        echo "Uninstalling hdparm..."
        sudo apt-get remove --purge -y hdparm
        if [ $? -ne 0 ]; then
          echo "Error: Unable to uninstall hdparm."
          exit $ERROR_UNINSTALL_FAILED
        fi
        echo "hdparm has been uninstalled."
    fi
  else
    echo "The disk is not an SSD."
  fi
fi

# Add to fstab if requested
if [ "$add_fstab" = true ]; then
    add_to_fstab
fi

if [[ -n "$install_systemd" || -n "$INVOCATION_ID" ]]; then
    mount_partition_func
fi
exit $ERROR_OK