#!/bin/bash

# Script name
SCRIPT_NAME="Enable Trim for USB SSD Drive"

# Display the script name
echo "### $SCRIPT_NAME ###"

# Define a variable for "usb_name"
usb_name="NVME Adapter"  # Replace "NVME Adapter" with the exact name of your USB device if necessary

# Define a variable for the mount point
mount_point="/mnt/usb"  # Replace this path with your desired mount point

# Check if hdparm is installed
if ! command -v hdparm &> /dev/null
then
  echo "hdparm is not installed. Installing..."
  sudo apt-get update -y
  sudo apt-get install -y hdparm
  install_hdparm=true
else
  install_hdparm=false
fi

# Retrieve USB device with lsusb and the grep command to find your USB device
usb_device=$(lsusb | grep "$usb_name")

# Retrieve bus and device numbers from the lsusb output and remove leading zeros
bus_number=$(echo $usb_device | awk '{print $2}' | sed 's/^0*//')
device_number=$(echo $usb_device | awk '{print $4}' | sed 's/^0*//;s/://')

# Display bus and device numbers
echo "Bus Number: $bus_number"
echo "Device Number: $device_number"

# Use dmesg to find both Product ID (Product) and Manufacturer
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
# Search for the line containing "Direct-Access" and extract the SCSI ID
scsi_id=$(dmesg | grep -i "Direct-Access" | grep -i "$manufacturer_info" | grep -i "$product_info" | grep -oP 'scsi \K(\d+:\d+:\d+:\d+)' | head -n 1)

if [ -z "$scsi_id" ]; then
  echo "Unable to find SCSI ID for this USB device."
  exit 1
fi

# Display the SCSI ID found
echo "SCSI ID: $scsi_id"

# Use dmesg to retrieve the device name from the SCSI ID
# Search for the line containing "sd $scsi_id" and extract the device name (e.g., sda)
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

# Extract partitions of /dev/$device_name, ignore the first line (column names), exclude the main disk (e.g., sda), and sort by size
partitions=$(lsblk -o NAME,SIZE /dev/$device_name | tail -n +2 | grep -v "^$device_name" | sort -k2 -h)

# Clean up tree characters (e.g., └─) and retrieve only the partition name (e.g., sda2)
clean_partitions=$(echo "$partitions" | sed 's/^[[:space:]]*└─//g' | sed 's/^[[:space:]]*├─//g')

# Extract the largest partition (the last one after sorting)
largest_partition=$(echo "$clean_partitions" | tail -n 1 | awk '{print $1}')

# Check if a partition was found
if [ -z "$largest_partition" ]; then
  echo "Unable to find a partition on /dev/$device_name."
  exit 1
fi

# Display the largest partition
echo "The largest partition is: /dev/$largest_partition"

# Retrieve and display the filesystem of the largest partition
filesystem=$(sudo blkid /dev/$largest_partition | awk -F ' ' '{for(i=1;i<=NF;i++) if($i ~ /TYPE=/) print $i}' | cut -d '=' -f 2)

# Display the filesystem format
echo "Filesystem of /dev/$largest_partition: $filesystem"

# Check if the filesystem is compatible with TRIM (e.g., ext4, f2fs, btrfs)
if [[ "$filesystem" == "ext4" || "$filesystem" == "f2fs" || "$filesystem" == "btrfs" ]]; then
  echo "The filesystem is compatible with TRIM."

  # Check if the device is an SSD
  rota=$(lsblk -d -o ROTA /dev/$largest_partition | tail -n 1)
  if [ "$rota" -eq 0 ]; then
    echo "The disk $device_name is an SSD."
  else
    echo "The disk $device_name is an HDD. TRIM is not applicable for HDDs."
  fi

  # Check if the device is an SSD and supports TRIM
  if [ "$rota" -eq 0 ] && sudo hdparm -I /dev/$largest_partition | grep -q "TRIM supported"; then
    echo "TRIM is supported for this disk."
    
    # Enable TRIM in real-time using fstrim
    echo "Running TRIM on partition /dev/$largest_partition..."
    sudo fstrim /dev/$largest_partition
    if [ $? -eq 0 ]; then
      echo "TRIM a été activé avec succès sur /dev/$largest_partition."
    else
      echo "Échec de l'exécution de TRIM sur /dev/$largest_partition."
    fi
  else
    echo "Le périphérique ne prend pas en charge TRIM."
  fi
else
  echo "Le système de fichiers $filesystem n'est pas compatible avec TRIM."
  echo "Les systèmes de fichiers compatibles avec TRIM sont : ext4, f2fs, btrfs."
fi

# Créer le point de montage s'il n'existe pas
if [ ! -d "$mount_point" ]; then
  echo "Création du point de montage : $mount_point"
  sudo mkdir -p "$mount_point"
fi

# Vérifier si le périphérique est déjà monté
if mount | grep -q "/dev/$largest_partition"; then
    echo "Le disque /dev/$largest_partition est déjà monté sur $mount_point."
else
    echo "Le disque /dev/$largest_partition n'est pas monté. Montage en cours..."
    sudo mount /dev/$largest_partition $mount_point
    if [ $? -eq 0 ]; then
        echo "Le disque /dev/$largest_partition a été monté avec succès sur $mount_point."
    else
        echo "Erreur lors du montage du disque/dev/$largest_partition."
    fi
fi

# Si hdparm a été installé, mais n'était pas présent avant, le retirer
if [ "$install_hdparm" = true ]; then
  echo "Désinstallation de hdparm..."
  sudo apt-get remove --purge -y hdparm
  sudo apt-get autoremove -y
  echo "hdparm a été désinstallé."
fi
 
