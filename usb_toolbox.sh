#!/bin/bash
#############################################
#                                           #
#             USB Drive Toolbox             #
#               v1.02                       #
#############################################
# Script name
SCRIPT_NAME="USB Drive Toolbox"
SCRIPT_VERSION="v1.02"  # Version

# Default parameters
label=""                # Default label of the USB device
partuuid=""             # Default PARTUUID of the partition
mount_point="/mnt/usb"  # Default mount point
install_hdparm=false	# Trigger to uninstall hdparm if installed by script
selected_partition=""
install_systemd=false	# Default to not install into systemd
add_fstab=false         # Default to not adding to fstab

# Function to display help information
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "This script enables TRIM on a USB SSD drive, mounts a USB SSD drive, and enables a systemd service for auto-mounting."
    echo
    echo "Options:"
    echo "  -i, --install          Install as a systemd service"
    echo "  -u, --uninstall        Remove the systemd service ONLY and exit"
    echo "  -m, --mount <path>     Specify the mount point (default: /mnt/usb)"
    echo "  -p, --partuuid <partuuid>  Specify the PARTUUID of the partition"
    echo "  -s, --sd <partition>   Specify the partition directly (avoid auto-detection)"
    echo "  -f, --fstab            Add the partition to /etc/fstab for automatic mounting"
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
}

# Function to uninstall hdparm
uninstall_hdparm() {
    echo "Uninstalling hdparm..."
    sudo apt-get remove --purge -y hdparm
    echo "hdparm has been uninstalled."
}

# Function to install the systemd service
install_systemd_service() {
    echo "Installing systemd service..."
    service_file="/etc/systemd/system/usb-drive-toolbox.service"

    # Create the systemd service file
    sudo bash -c "cat > $service_file <<EOF
[Unit]
Description=USB Drive Toolbox

[Service]
ExecStart=$0
Restart=always
User=root
Environment=LABEL=$label
Environment=PARTUUID=$partuuid
Environment=MOUNT_POINT=$mount_point
Environment=SELECTED_PARTITION=$selected_partition

[Install]
WantedBy=multi-user.target
EOF"

    # Reload systemd units and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable usb-drive-toolbox.service
    sudo systemctl start usb-drive-toolbox.service

    echo "Systemd service installed and enabled."

    # Install the script itself in /usr/local/bin/
    script_path="/usr/local/bin/usb-drive-toolbox"
    sudo cp "$0" "$script_path"
    sudo chmod +x "$script_path"
    echo "Script installed to $script_path"
}

# Function to remove the systemd service
remove_systemd_service() {
    service_file="/etc/systemd/system/usb-drive-toolbox.service"

    # Check if the systemd service file exists
    if [ -f "$service_file" ]; then
        echo "Removing systemd service..."
        sudo systemctl stop usb-drive-toolbox.service
        sudo systemctl disable usb-drive-toolbox.service
        sudo rm -f "$service_file"
        sudo systemctl daemon-reload
        echo "Systemd service removed."
    else
        echo "Systemd service file does not exist. Nothing to remove."
    fi
}

# Function to add the partition to /etc/fstab
add_to_fstab() {
    echo "Adding the partition to /etc/fstab for automatic mounting..."
    
    # Check if the entry is already present in fstab
    if grep -q "$partuuid" /etc/fstab; then
        echo "The partition is already listed in /etc/fstab."
    else
        # Add the fstab entry using PARTUUID
        echo "PARTUUID=$partuuid $mount_point $filesystem defaults 0 2" | sudo tee -a /etc/fstab
        echo "The partition has been added to /etc/fstab."
    fi
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--install)
            install_systemd=true
            shift # Remove the argument from the list
            ;;
        -u|--uninstall)
            remove_systemd_service
            exit 0
            ;;
        -v|--version)
            echo "Script version: $SCRIPT_VERSION"
            exit 0
            ;;
        -m|--mount)
            mount_point="$2"
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

# Check if -f and -i are used together
if [ "$install_systemd" = true ] && [ "$add_fstab" = true ]; then
    echo "Error: You cannot use both -i (install systemd service) and -f (add to fstab) at the same time."
    exit 1
fi

# Use systemd passed environment variables if available
if [ -n "$LABEL" ]; then
    label="$LABEL"
fi
if [ -n "$PARTUUID" ]; then
    partuuid="$PARTUUID"
fi
if [ -n "$SELECTED_PARTITION" ]; then
    selected_partition="$SELECTED_PARTITION"
fi

# Find the partition using partuuid, label, or sda
echo "Finding partition with provided identifiers..."

# Search by partuuid first
if [ -n "$partuuid" ]; then
    selected_partition=$(blkid | grep "PARTUUID=\"$partuuid\"" | awk '{print $1}' | sed 's/://')
    echo "The selected partition with PARTUUID is: $selected_partition"
    # If partuuid is found, find label
    if [ -n "$selected_partition" ]; then
        label=$(blkid $selected_partition | grep "LABEL=" | cut -d '=' -f 2)
    fi
fi

# If no partuuid, try label
if [ -z "$selected_partition" ] && [ -n "$label" ]; then
    selected_partition=$(blkid | grep "LABEL=\"$label\"" | awk '{print $1}' | sed 's/://')
    echo "The selected partition with LABEL is: $selected_partition"
    # If label is found, find partuuid
    if [ -n "$selected_partition" ]; then
        partuuid=$(blkid $selected_partition | grep "PARTUUID=" | cut -d '=' -f 2)
    fi
fi

# If no partuuid or label, try sda
if [ -n "$selected_partition" ]; then
    echo "The selected partition with SDA is: $selected_partition"
    
    # If no partuuid or label, attempt to find label and partuuid
    if [ -n "$selected_partition" ]; then
        label=$(blkid $selected_partition | grep "LABEL=" | cut -d '=' -f 2)
        partuuid=$(blkid $selected_partition | grep "PARTUUID=" | cut -d '=' -f 2)
    fi
fi

# If still no partition found, take the last USB disk found in dmesg
if [ -z "$selected_partition" ]; then
    echo "No partition found for the provided identifiers. Taking the last USB disk found in dmesg..."

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
    fi
fi

if [ -z "$selected_partition" ]; then
    echo "No partition found."
    exit 1
fi

# Display the selected partition
echo "The selected partition is: $selected_partition"

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
        uninstall_hdparm
    fi
  else
    echo "The disk is not an SSD."
  fi
fi

# Add to fstab if requested
if [ "$add_fstab" = true ]; then
    add_to_fstab
fi

# Create the mount point if it doesn't exist
if [ ! -d "$mount_point" ]; then
  sudo mkdir -p "$mount_point"
  echo "Created mount point: $mount_point"
fi

# Check if the device is already mounted
if mount | grep -q "$selected_partition"; then
    echo "The disk $selected_partition is already mounted at $mount_point."
else
    echo "The disk $selected_partition is not mounted. Mounting now..."
    sudo mount $selected_partition $mount_point
    if [ $? -eq 0 ]; then
        echo "The disk $selected_partition was successfully mounted at $mount_point."
    else
        echo "Error while mounting $selected_partition."
    fi
fi
