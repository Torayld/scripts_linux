#!/bin/bash

# Variables
WIFI_SSID="YourSSID"              # Wi-Fi network name to connect to
WIFI_PASSWORD="YourPassword"      # Wi-Fi password (leave empty for no password)
INTERFACE="wlan0"                 # Wireless interface name (change if necessary)
HOTSPOT_SSID="Hotspot"            # Hotspot name
HOTSPOT_PASSWORD="hotspot123"     # Hotspot password
HOTSPOT_CONNECTION_NAME="HotspotConnection"  # Hotspot connection name

# Parameters
MAX_WAIT_TIME=30  # Duration in minutes to attempt connection (modifiable)
CHECK_INTERVAL=30  # Interval in seconds to check SSID availability (modifiable)
ENABLE_HOTSPOT=true  # Enable Hotspot if Wi-Fi is unavailable (true/false)
HOTSPOT_ACTIVE=false  # Indicates whether the Hotspot is already active
HOTSPOT_START_WAIT_TIME=5  # Delay in minutes before starting the Hotspot (modifiable)

# Function to check if the Wi-Fi SSID is available
check_wifi_availability() {
    # Check if the SSID is available using nmcli
    if nmcli dev wifi | grep -q "$WIFI_SSID"; then
        return 0  # SSID is available
    else
        return 1  # SSID is not available
    fi
}

# Function to reset wlan0 interface if nmcli fails
reset_wifi_interface() {
    echo "nmcli cannot find Wi-Fi networks, attempting to reset wlan0 interface..."

    # Check if /sbin/ip is available to manipulate the network interface
    if command -v /sbin/ip &>/dev/null; then
        echo "Using ip to reset wlan0 interface"
        /sbin/ip link set wlan0 down
        sleep 10
        /sbin/ip link set wlan0 up
    elif command -v ifconfig &>/dev/null; then
        echo "Using ifconfig to reset wlan0 interface"
        /sbin/ifconfig wlan0 down
        sleep 10
        /sbin/ifconfig wlan0 up
    else
        echo "Error: No suitable command (ip or ifconfig) found to manipulate the network interface."
        exit 1
    fi
}

# Function to check if Wi-Fi connection is successful
check_wifi_connection() {
    ping -c 1 8.8.8.8 &>/dev/null
    return $?
}

# Function to start the Hotspot if necessary using nmcli
start_hotspot() {
    echo "Wi-Fi is unavailable, starting Hotspot after a $HOTSPOT_START_DELAY seconds delay..."

    # Start Hotspot using nmcli
    nmcli device wifi hotspot ssid "$HOTSPOT_SSID" password "$HOTSPOT_PASSWORD" ifname "$INTERFACE" con-name "$HOTSPOT_CONNECTION_NAME"
    HOTSPOT_ACTIVE=true  # Hotspot is now active
    echo "Wi-Fi Hotspot started successfully. SSID: $HOTSPOT_SSID, Password: $HOTSPOT_PASSWORD"
}

# Function to stop the Hotspot if a successful Wi-Fi connection is made
stop_hotspot() {
    echo "Wi-Fi connection successful, stopping Hotspot..."

    # Stop the Hotspot using nmcli
    nmcli connection down "$HOTSPOT_CONNECTION_NAME" || echo "Failed to stop Hotspot."

    # Delete the Hotspot connection
    nmcli connection delete "$HOTSPOT_CONNECTION_NAME" || echo "Failed to delete Hotspot connection."

    HOTSPOT_ACTIVE=false  # Hotspot is no longer active
    echo "Hotspot stopped and connection deleted."
}

# Loop to check Wi-Fi availability at regular intervals
elapsed_time=0
while [ $elapsed_time -lt $((MAX_WAIT_TIME * 60)) ]; do
    if check_wifi_availability; then
        echo "Wi-Fi network $WIFI_SSID found. Attempting to connect..."

        # If a password is defined, use nmcli to connect with the password
        if [ -n "$WIFI_PASSWORD" ]; then
            nmcli dev wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD"
        else
            nmcli dev wifi connect "$WIFI_SSID"
        fi

        if check_wifi_connection; then
            echo "Wi-Fi connection successful."
            stop_hotspot  # Stop Hotspot if connection is successful
            exit 0
        else
            echo "Wi-Fi connection failed, retrying..."
        fi
    else
        echo "Network $WIFI_SSID is not available. Checking again in $CHECK_INTERVAL seconds..."

        # If Hotspot is not already active, reset the Wi-Fi interface
        if [ "$HOTSPOT_ACTIVE" = false ]; then
            reset_wifi_interface
        fi
    fi

    sleep $CHECK_INTERVAL
    elapsed_time=$((elapsed_time + CHECK_INTERVAL))

    # If the maximum wait time has passed and Hotspot is not active, start the Hotspot
    if [ $elapsed_time -ge $((HOTSPOT_START_WAIT_TIME * 60)) ] && [ "$HOTSPOT_ACTIVE" = false ] && [ "$ENABLE_HOTSPOT" = true ]; then
        start_hotspot
    fi
done
