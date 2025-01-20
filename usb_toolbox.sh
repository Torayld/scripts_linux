#!/bin/bash
# -------------------------------------------------------------------
# USB Drive Toolbox
#
# Script to mount, auto-mount, and enable TRIM on a USB SSD drive
#
# Description:
# This script allows you to mount a USB SSD drive, enable TRIM support,
# umount the partition, manage fstab entries, and install a systemd service
# Version: 1.0.6
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="v1.06"  # Version

# Default parameters
label=""                # Default label of the USB device
partuuid=""             # Default PARTUUID of the partition
mount_point="/mnt/usb"  # Default mount point
install_hdparm=false    # Trigger to uninstall hdparm if installed by script
selected_partition=""
install_systemd=false   # Default to not install into systemd
uninstall_systemd=false # Default to not uninstall from systemd
add_fstab=false         # Default to not adding to fstab
remove_fstab=false      # Default to not removing from fstab

# Function to display help information
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "This script enables TRIM on a USB SSD drive, mounts a USB SSD drive, and enables a systemd service for auto-mounting."
    echo
    echo "Options:"
    echo "  -is, --install-systemd Install as a systemd service"
    echo "  -rs, --remove-systemd  Remove the systemd service ONLY and exit"
    echo "  -m, --mount <path>     Specify the mount point (default: /mnt/usb)"
    echo "  -u, --umount <path>    Umount the partition and remove the mount point"
    echo "  -p, --partuuid <partuuid>  Specify the PARTUUID of the partition"
    echo "  -s, --sd <partition>   Specify the partition directly (avoid auto-detection)"
    echo "  -f, --fstab            Add the partition to /etc/fstab for automatic mounting"
    echo "  -rf, --remove-fstab    Remove the partition from /etc/fstab for automatic mounting"
    echo "  -v, --version          Display the script version"
    echo "  -h, --help             Display this help message"
    echo
    echo "Priority of parameters:"
    echo "  1. --partuuid <partuuid>: First, the script will attempt to use PARTUUID to identify the partition."
    echo "  2. --sd <partition>: If no PARTUUID is provided, the script will then use the partition identifier (e.g., /dev/sda1)."
    echo "  3. --label <label>: If neither PARTUUID nor partition identifier is provided, the script will search for a partition with the specified label."
    echo "  4. If none of the above is provided, the script will search for the last connected USB disk."
    echo
    echo "Example:"
    echo "  $0 -i                  Install the script as a systemd service"
    echo "  $0 --help              Display this help message"
    echo "  $0 -v                  Display the script version"
    echo "  $0 -m /path/to/mount   Specify the mount point"
    echo "  $0 -p <PARTUUID>       Specify the PARTUUID of the partition"
    echo "  $0 -s <partition>      Specify the selected partition directly"
    echo "  $0 -u                  Remove the systemd service"
    echo "  $0 -f                  Add the partition to /etc/fstab"
    echo
    echo "Error Codes:"
    echo "  1x   - Param error"
    echo "  2x   - No partition found"
    echo "  3x   - Error while mounting the partition"
    echo "  4x   - Error while adding to /etc/fstab"
    echo "  5x   - Error while removing from /etc/fstab"
    echo "  6x   - Error while installing systemd service"
    echo "  7x   - Error while installing/uninstalling hdparm"
    echo "  8x   - Error while umounting the partition"
}

fstap_allready=false
# Fonction pour vérifier si la partition est déjà dans /etc/fstab
check_fstab() {
    # Vérifie si la PARTUUID ou la LABEL est déjà dans /etc/fstab
    if grep -q "$partuuid" /etc/fstab || grep -q "$label" /etc/fstab; then
        fstap_allready=true
    fi
}

# Function to install the systemd service
install_systemd_service() {
    check_fstab
    if [ "$fstap_allready" = true ]; then
        echo "Error: The partition is already in /etc/fstab."
        exit 60
    fi

    # Call the child script
    if [ ! -f "./systemd.sh" ]; then
        echo "systemd.sh not found to install service."
        exit 61
    fi

    echo "Installing systemd service..."
    $return=$(./systemd.sh -exe $0 -cs -csf -n usb_mount -env 'PARTUUID="'$partuuid'" MOUNT_POINT="'$mount_point'"' \
        -d 'Mounting USB Drive for Apache/Mariadb before start' -b mariadb.service)

    # Check the exit status of the child script
    if [ $return -eq 0 ]; then
        echo "Systemd service installed and enabled."
    else
        echo "systemd.sh encountered an error : "$return
        exit 62
    fi
}

# Function to remove the systemd service
remove_systemd_service() {

    # Search for the MOUNT_POINT value in /etc/systemd/system/usb_mountX.service files
    result=$(grep -rl "MOUNT_POINT=\"$mount_point\"" /etc/systemd/system/usb_mount*.service)
    if [ -n "$result" ]; then
        echo "Found MOUNT_POINT=$mount_point in the following service file(s):"
        echo "$result"
    else
        echo "No service files found with MOUNT_POINT=$mount_point."
        exit 60
    fi

    if [ ! -f "./systemd.sh" ]; then
        echo "systemd.sh not found to install service."
        exit 61
    fi

    ./systemd.sh -exe $0 -rs usb_mount1.service

    # Check the exit status of the child script
    if [ $? -eq 0 ]; then
        echo "Systemd service installed and enabled."
    else
        echo "systemd.sh encountered an error."
        exit 62
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
            exit 4
        fi
        echo "The partition has been added to /etc/fstab."
    fi
}

# Function to remove the partition from /etc/fstab
remove_from_fstab() {
    # Check if $partuuid is empty
    if [ -z "$partuuid" ]; then
        echo "Error: PARTUUID is empty. Cannot remove from /etc/fstab."
        exit 6
    fi
    
    echo "Removing the partition from /etc/fstab for automatic mounting..."

    # Check if the entry exists in fstab
    if grep -q "$partuuid" /etc/fstab; then
        sudo sed -i "/$partuuid/d" /etc/fstab
        if [ $? -ne 0 ]; then
            echo "Error: Unable to modify /etc/fstab."
            exit 5
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
            exit 30
        fi
    else
        echo "The disk $selected_partition is not mounted. Mounting now..."
        sudo mount $selected_partition $mount_point
        if [ $? -eq 0 ]; then
            echo "The disk $selected_partition was successfully mounted at $mount_point."
        else
            echo "Error while mounting $selected_partition."
            exit 31
        fi
    fi
}

# Function to unmount the partition and remove the mount point directory if it's empty
umount_partition_func() {
    # Ensure that the argument provided with -u is not empty
    if [ -z "$umount_target" ]; then
        echo "Error: You must specify a partition or mount point with the -u option."
        exit 40
    fi
    
    echo "Unmounting $umount_target..."

    # Check if the argument is a partition (e.g., /dev/sda) or a mount point (e.g., /mnt/usb)
    if [[ "$umount_target" =~ ^/dev/ ]]; then
        # If it's a partition, find the corresponding mount point using mount command
        mount_point=$(mount | grep "$umount_target" | awk '{print $3}')

        if [ -z "$mount_point" ]; then
            echo "Error: $umount_target is not mounted."
            exit 41
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
                echo "The mount point directory $mount_point has been removed."
            fi
        else
            echo "Error while unmounting $mount_point."
            echo $(lsof | grep $mount_point)
            exit 42
        fi
    else
        echo "$mount_point is not mounted."
        exit 43
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
        -is|--install-systemd)
            install_systemd=true
            shift # Remove the argument from the list
            ;;
        -rs|--remove-systemd)
            uninstall_systemd=true
            shift
            ;;
        -v|--version)
            echo "Script version: $SCRIPT_VERSION"
            exit 0
            ;;
        -m|--mount)
            mount_point="$2"
            shift 2 # Remove the argument and value from the list
            ;;
        -u|--umount)
            umount_target="$2"
            shift 2 # Remove the argument and value from the list
            ;;
        -p|--partuuid)
            partuuid="$2"
            shift 2 # Remove the argument and value from the list
            ;;
        -s|--sd)
            selected_partition="$2"
            shift 2 # Remove the argument and value from the list
            ;;
        -f|--fstab)
            add_fstab=true
            shift # Remove the argument from the list
            ;;
        -rf|--remove-fstab)
            remove_fstab=true
            shift # Remove the argument from the list
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            display_help
            exit 1
            ;;
    esac
done

# If the -u or --umount option is used, unmount the partition
if [ -n "$umount_target" ]; then
    umount_partition_func
    exit 0
fi

# Check if -f and -i are used together
if [ "$uninstall_systemd" = true ] && [ "$remove_fstab" = true ]; then
    echo "Error: You cannot use both -u (uniinstall systemd service) and -rf (remove fstab) at the same time."
    exit 12
fi

# If the -rs option is used, remove the systemd service
if [ "$uninstall_systemd" = true ]; then
    remove_systemd_service
    exit 0
fi

# Check if -f and -i are used together
if [ "$install_systemd" = true ] && [ "$add_fstab" = true ]; then
    echo "Error: You cannot use both -i (install systemd service) and -f (add to fstab) at the same time."
    exit 13
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
    exit 2
fi

# Display the selected partition
echo "The selected partition is: $selected_partition"
echo "The Label is: $label"
echo "The PARTUUID is: $partuuid"

# If the -rf option is used, remove the entry from fstab
if [ "$remove_fstab" = true ]; then
    remove_from_fstab
    exit 0
fi

# If the -i option is used, install the systemd service
if [ "$install_systemd" = true ]; then
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
        exit 70
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
          exit 71
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

if [ "$install_systemd" = false ]; then
    mount_partition_func
fi
exit 0