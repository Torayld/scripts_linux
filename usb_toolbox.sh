#!/bin/bash
#############################################
#                                           #
#              USB Drive Toolbox            #
#               v1.01                       #
#############################################
# Script name
SCRIPT_NAME="USB Drive Toolbox"
SCRIPT_VERSION="v1.01"  # Define the version of the script

# Default parameters
usb_name="NVME Adapter"  # Default USB device name
mount_point="/mnt/usb"   # Default mount point
install_systemd=false
remove_systemd=false
selected_partition=""  # Default is empty, will be set by -s/--sd option

# Function to display help information
display_help() {
    echo "Usage: $0 [options]"
    echo
    echo "This script enables TRIM on a USB SSD drive."
    echo
    echo "Options:"
    echo "  -i, --install          Install as a systemd service"
    echo "  -r, --remove           Remove the systemd service"
    echo "  -m, --mount <path>     Specify the mount point (default: /mnt/usb)"
    echo "  -u, --usb <device>     Specify the USB device name (default: NVME Adapter)"
    echo "  -s, --sd <partition>   Specify the selected partition directly"
    echo "  -v, --version          Display the script version"
    echo "  -h, --help             Display this help message"
    echo
    echo "Example:"
    echo "  $0 -i                  Install the script as a systemd service"
    echo "  $0 --help              Display this help message"
    echo "  $0 -v                  Display the script version"
    echo "  $0 -m /path/to/mount   Specify the mount point"
    echo "  $0 -u 'USB Device'     Specify the USB device name"
    echo "  $0 -r                  Remove the systemd service"
    echo "  $0 -s /dev/sda1        Specify the selected partition directly"
}

# Function to install the systemd service
install_systemd_service() {
    echo "Installing systemd service..."

    # Install the script itself in /usr/local/bin/
    script_path="/usr/local/bin/usb-drive-toolbox"
    sudo cp "$0" "$script_path"
    sudo chmod +x "$script_path"
    echo "Script installed to $script_path"

    service_file="/etc/systemd/system/usb-drive-toolbox.service"

    # Create the systemd service file with the selected_partition value (if provided)
    sudo bash -c "cat > $service_file <<EOF
[Unit]
Description=USB Drive Toolbox - Mount and Enable TRIM for USB SSD

[Service]
ExecStart=$script_path
Restart=always
User=root
Environment=USB_NAME=${usb_name}
Environment=MOUNT_POINT=${mount_point}
Environment=SELECTED_PARTITION=${selected_partition}

[Install]
WantedBy=multi-user.target
EOF"

    # Reload systemd units and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable usb-drive-toolbox.service
    sudo systemctl start usb-drive-toolbox.service

    echo "Systemd service installed and enabled."
}

# Function to remove the systemd service
remove_systemd_service() {
    echo "Removing systemd service..."
    sudo systemctl stop usb-drive-toolbox.service
    sudo systemctl disable usb-drive-toolbox.service
    sudo rm -f /etc/systemd/system/usb-drive-toolbox.service
    sudo systemctl daemon-reload
    echo "Systemd service removed."
}

# Use systemd passed environment variables if available
if [ -n "$USB_NAME" ]; then
  usb_name="$USB_NAME"
fi
if [ -n "$MOUNT_POINT" ]; then
  mount_point="$MOUNT_POINT"
fi
if [ -n "$SELECTED_PARTITION" ]; then
  selected_partition="$SELECTED_PARTITION"
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--install)
            install_systemd=true
            shift # Remove the argument from the list
            ;;
        -r|--remove)
            remove_systemd=true
            shift # Remove the argument from the list
            ;;
        -v|--version)
            echo "Script version: $SCRIPT_VERSION"
            exit 0
            ;;
        -m|--mount)
            mount_point="$2"
            shift 2 # Remove the argument and value from the list
            ;;
        -u|--usb)
            usb_name="$2"
            shift 2 # Remove the argument and value from the list
            ;;
        -s|--sd)
            selected_partition="$2"
            shift 2 # Remove the argument and value from the list
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

# If the -i option is used, install the systemd service
if [ "$install_systemd" = true ]; then
    install_systemd_service
    exit 0
fi

# If the -r option is used, remove the systemd service
if [ "$remove_systemd" = true ]; then
    remove_systemd_service
    exit 0
fi

# Use the selected_partition if it was provided
if [ -n "$selected_partition" ]; then
    echo "Using the provided partition: $selected_partition"
else
    # Retrieve the USB device with lsusb and grep
    usb_device=$(lsusb | grep "$usb_name")

    # Retrieve bus and device numbers from the lsusb output
    bus_number=$(echo $usb_device | awk '{print $2}' | sed 's/^0*//')
    device_number=$(echo $usb_device | awk '{print $4}' | sed 's/^0*//;s/://')

    # Display bus and device numbers
    echo "Bus Number: $bus_number"
    echo "Device Number: $device_number"

    # Use dmesg to find both Product ID and Manufacturer
    product_info=$(dmesg | grep -i "usb $bus_number-$device_number" | grep -oP 'Product:\s+\K([^\s]+)')
    manufacturer_info=$(dmesg | grep -i "usb $bus_number-$device_number" | grep -oP 'Manufacturer:\s+\K([^\s]+)')

    # Check if product and manufacturer info were retrieved successfully
    if [ -z "$product_info" ] || [ -z "$manufacturer_info" ]; then
      echo "Unable to find product ID or manufacturer in dmesg logs."
      exit 1
    fi

    # Display product ID and manufacturer
    echo "Product ID found: $product_info"
    echo "Manufacturer found: $manufacturer_info"

    # Use dmesg to find the SCSI line associated with the device
    scsi_id=$(dmesg | grep -i "Direct-Access" | grep -i "$manufacturer_info" | grep -i "$product_info" | grep -oP 'scsi \K(\d+:\d+:\d+:\d+)' | head -n 1)

    if [ -z "$scsi_id" ]; then
      echo "Unable to find SCSI ID for this USB device."
      exit 1
    fi

    # Display the SCSI ID found
    echo "SCSI ID: $scsi_id"

    # Use dmesg to retrieve the device name from the SCSI ID
    device_name=$(dmesg | grep "sd $scsi_id" | grep -oP "sd $scsi_id: \[([^\]]+)\]" | head -n 1 | sed 's/.*\[//;s/\]//' | sed 's/^[[:space:]]*|-//g' | sed 's/^[[:space:]]*`-//g')

    # Check if the device name was found
    if [ -z "$device_name" ]; then
      echo "Unable to find device name from the SCSI ID."
      exit 1
    fi

    # Display the device name found
    echo "Storage device name: /dev/$device_name"

    # List all partitions of this device and display
    echo "List of partitions of /dev/$device_name:"
    lsblk -o NAME,SIZE /dev/$device_name

    # Extract partitions (ignore "disk" type and the header) and sort by size
    partitions=$(lsblk -o NAME,SIZE,TYPE $device_name | grep -v "disk" | grep -v "NAME" | sort -k2 -h)

    # Clean up tree characters (e.g.,├─, └─ or |-, `- in systemctl) and retrieve only the partition name
    clean_partitions=$(echo "$partitions" | sed 's/^[[:space:]]*└─//g' | sed 's/^[[:space:]]*├─//g' | sed 's/^[[:space:]]*`-//g' | sed 's/^[[:space:]]*|-//g')


    # Extract the largest partition (the last one after sorting)
    selected_partition=$(echo "$clean_partitions" | tail -n 1 | awk '{print $1}')

    # Check if a partition was found
    if [ -z "$selected_partition" ]; then
      echo "Unable to find a partition on /dev/$device_name."
      exit 1
    fi

    # Display the selected partition
    echo "The selected partition is: $selected_partition"
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
    echo "The disk $device_name is an SSD."

    # Install hdparm before checking TRIM support if necessary
    if ! command -v hdparm &> /dev/null; then
      echo "hdparm is not installed. Installing..."
      sudo apt-get update -y
      sudo apt-get install -y hdparm
    fi

    # Check if the device supports TRIM
    if sudo hdparm -I $selected_partition | grep -q "TRIM supported"; then
      echo "TRIM is supported for this disk."
      
      # Enable TRIM in real-time using fstrim
      echo "Running TRIM on partition $selected_partition..."
      sudo fstrim $selected_partition
      if [ $? -eq 0 ]; then
        echo "TRIM was successfully enabled on $selected_partition."
      else
        echo "Failed to run TRIM on $selected_partition."
      fi
    else
      echo "The device does not support TRIM."
    fi
  else
    echo "The disk $device_name is an HDD. TRIM is not applicable for HDDs."
  fi
else
  echo "The filesystem $filesystem is not compatible with TRIM."
  echo "The supported filesystems for TRIM are: ext4, f2fs, btrfs."
fi

# Create the mount point if it doesn't exist
if [ ! -d "$mount_point" ]; then
  sudo mkdir -p "$mount_point"
  echo "Created mount point: $mount_point"
fi

# Check if device allready mounted
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
