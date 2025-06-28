#!/bin/bash
# -------------------------------------------------------------------
# Function for network operations
# Version: 1.0.1
# Author: Torayld
# -------------------------------------------------------------------


# Function to check interface UP state and bring it UP if it is down
# If the interface is still down after multiple retries, exit with an error
# The function will use /sbin/ip or ifconfig based on availability
# Can also reset the interface if specified
# Param 1: Interface name (e.g., wlan0)
# Param 2: Number of retries (default: 3)
# Param 3: Reset interface if true (default: false)
check_interface() {
    local interface=$1
    local retries=${2:-3}  # Retry, default 3.
    local reset_interface=${3:-false}  # Reset interface if true

    # Vérification des paramètres
    if [ -z "$interface" ]; then
        echo "Error: interface parameter is required."
        return 1
    fi

    if [ "$reset_interface" = true ]; then
        echo "Resetting interface $interface..."
        if command -v /sbin/ip &>/dev/null; then
            if /sbin/ip link show "$interface" | grep -q "UP"; then
                echo "Using /sbin/ip to down $interface"
                sudo /sbin/ip link set "$interface" down
                sleep 2
            else
                echo "Interface $interface is already DOWN."
            fi
        elif command -v ifconfig &>/dev/null; then
            if ifconfig $interface | grep -q "UP"; then
                echo "Using ifconfig to down $interface"
                sudo ifconfig "$interface" down
                sleep 2
            else
                echo "Interface $interface is already DOWN."
            fi
        else
            echo "Error: No suitable tool (/sbin/ip or ifconfig) found to manipulate the network interface."
            exit 1
        fi
    fi

    if command -v /sbin/ip &>/dev/null; then
        
        if /sbin/ip link show "$interface" | grep -q "UP"; then
            echo "Interface $interface is already UP."
            return 0
        else
            echo "Using /sbin/ip to up $interface"
            sudo /sbin/ip link set "$interface" up
            sleep 2
            return 0
        fi
     elif command -v ifconfig &>/dev/null; then
        echo "Using ifconfig"
        if ifconfig $interface | grep -q "UP"; then
            echo "Interface $interface is already UP."
            return 0
        else
            echo "Using ifconfig to up $interface"
            sudo ifconfig "$interface" up
            sleep 2
            return 0
        fi
    else
        echo "Error: No suitable tool (/sbin/ip or ifconfig) found to manipulate the network interface."
        exit 1
    fi

    # Si l'interface n'est toujours pas UP, réessayer si le nombre d'essais n'est pas écoulé
    if [ "$retries" -gt 0 ]; then
        check_interface "$interface" $((retries - 1))
        echo "Retrying to bring interface $interface UP. Attempts remaining: $((retries - 1))"
    else
        echo "Failed to bring interface $interface UP after multiple attempts."
        exit 1
    fi
}

# Function to check if an IP address is assigned to the interface
# The function will use /sbin/ip or ifconfig based on availability
# Param 1: Interface name (e.g., wlan0)
# Return: 0 if successful, 1 if failed
return_ip_addr=''
return_ip_gateway_addr=''
get_ip_assigned() {
    local interface=$1

    # Vérification des paramètres
    if [ -z "$interface" ]; then
        echo "Error: interface parameter is required."
        return 1
    fi

    if command -v /sbin/ip &>/dev/null; then
        return_ip_addr=$(/sbin/ip -o -4 addr show "wlan0" | grep -oP 'inet \K[\d.]+')
        return_ip_gateway_addr=$(/sbin/ip route show dev "$interface" | grep default | awk '{print $3}')
        if [ ! -n "$return_ip_addr" ]; then
            echo "No IP address assigned to interface $interface with /sbin/ip."
            return 1
        fi
    elif command -v ifconfig &>/dev/null; then
        return_ip_addr=$(ifconfig "$interface" | grep 'inet ' | awk '{print $2}')
        return_ip_gateway_addr=$(route -n | grep '^0.0.0.0' | awk '{print $2}')
        if [ ! -n "$return_ip_addr" ]; then
            echo "No IP address assigned to interface $interface with ifconfig."
            return 1
        fi
    else
        echo "Error: No suitable tool (ip or ifconfig) found to manipulate the network interface."
        exit 1
    fi

    echo "Interface $interface IP address: $return_ip_addr"
    echo "Default gateway : $return_ip_gateway_addr"
    return 0
}

# Function to check if internet connectivity is available on a specific interface
# Param 1: Interface name (e.g., wlan0)
# Param 2: Destination IP address to ping (default:8.8.8.8)
# Return: 0 if successful, 1 if failed
check_ping() {
    local interface="$1" # Interface to check (e.g., wlan0)
    local destination=${2:-"8.8.8.8"}  # Destination IP address to ping
    
    if [ -z "$interface" ] || [ -z "$destination" ]; then
        echo "Error: No interface specified."
        return 1
    fi

    # Use ping with the specified interface
    if ping -I "$interface" -c 1 -W 2 $destination &>/dev/null; then
        echo "Ping to $destination successful on $interface."
        return 0
    else
        echo "Ping to $destination failed on $interface."
        return 1
    fi
}

# Function to check if DNS is available on the interface
# Param 1: Interface name (e.g., wlan0)
# Param 2: DNS name to check (default: www.google.com)
# Return: 0 if DNS is available, 1 if not available, 2 if DNS server is not responding
get_dns_available() {
    local interface=$1
    local dns_name_check=${2:-"www.google.com"}  # DNS name to check
    local dns_check_failed=false
    return_dns_server=''

    # Check parameters
    if [ -z "$interface" ]; then
        echo "Error: interface parameter is required."
        return 1
    fi

    # Get the DNS server for the interface
    if command -v resolvectl >/dev/null 2>&1; then
        echo "Using resolvectl to get DNS for interface $interface"
        return_dns_server=$(resolvectl dns "$interface" 2>/dev/null | awk '{print $2}')
    elif command -v nmcli >/dev/null 2>&1; then
        echo "Using nmcli to get DNS for interface $interface"
        local connection_name=$(nmcli -t -f DEVICE,NAME connection show --active | grep "^$interface:" | cut -d: -f2)
        return_dns_server=$(nmcli -t -f IP4.DNS connection show "$connection_name" 2>/dev/null | head -n 1 | sed 's/^IP4\.DNS\[[0-9]*\]://')
    else
        echo "Error: No suitable tool (resolvectl,nmcli) found to get dns."
        exit 1
    fi

    echo "DNS server found: $return_dns_server for interface $interface."

    # Check DNS server availability
     echo "Checking DNS $return_dns_server on interface $interface for $dns_name_check..."
    if command -v dig >/dev/null 2>&1; then
        echo "Using dig"
        if ! dig @${return_dns_server} $dns_name_check -I "$interface" +short >/dev/null 2>&1; then
            dns_check_failed=true
        fi
    elif command -v nslookup >/dev/null 2>&1; then
        echo "Using nslookup"
        if ! nslookup $dns_name_check "$return_dns_server" "$interface" >/dev/null 2>&1; then
            dns_check_failed=true
        fi
    elif command -v curl >/dev/null 2>&1; then
        echo "Using curl"
        if ! curl --interface "$interface" --silent --max-time 5 --head "https://$dns_name_check" >/dev/null 2>&1; then
            dns_check_failed=true
        fi
    elif command -v wget >/dev/null 2>&1; then
        echo "Using wget"
        if ! wget --timeout=5 --spider --bind-address "$(ip addr show "$interface" | grep inet | awk '{print $2}' | cut -d/ -f1)" "https://$dns_name_check" >/dev/null 2>&1; then
            dns_check_failed=true
        fi
    else
        echo "Error: No suitable tool (dig,nslookup,curl,wget) found to check dns."
        exit 1
    fi

    

    if [ -n "$return_dns_server" ]; then
        if [ "$dns_check_failed" = true ]; then
            echo "DNS server $return_dns_server is not responding on interface $interface."
            return 2
        else
            return 0
        fi
    else
        echo "No DNS server suitable for interface $interface."
        return 1
    fi
}

# Function to check if the Wi-Fi is blocked (soft or hard)
# The function will use rfkill to check the status of Wireless LAN devices
# Param 1: Interface name (e.g., wlan0)
# Return: 0 if Wi-Fi is available, 82 if soft blocked, 281 if hard blocked, 80 if WLAN interface not found
check_wifi_block() {
    local iface=${1:-"wlan0"}   # Default interface to wlan0 if not provided
    local rfkill_id
    rfkill_id=$(rfkill list | awk -v iface="$iface" '
        BEGIN { RS=""; FS="\n" }
        {
            for (i=1; i<=NF; i++) {
                if ($i ~ iface) {
                    match($1, /^[0-9]+/);
                    print substr($1, RSTART, RLENGTH);
                    exit
                }
            }
        }'
    )

    if [[ -z "$rfkill_id" ]]; then
        echo "No rfkill entry found for interface: $iface"
        return $ERROR_WLAN_NOT_FOUND
    fi

    echo "Found rfkill ID: $rfkill_id for interface: $iface"

    rfkill list "$rfkill_id"

    local soft_blocked hard_blocked
    soft_blocked=$(rfkill list "$rfkill_id" | grep -i 'Soft blocked' | awk '{print $3}')
    hard_blocked=$(rfkill list "$rfkill_id" | grep -i 'Hard blocked' | awk '{print $3}')

    echo "Soft Blocked: $soft_blocked"
    echo "Hard Blocked: $hard_blocked"
    if [[ "$hard_blocked" == "yes" ]]; then
        echo "Interface is hard-blocked. You may need to toggle a hardware switch (e.g., WiFi key or BIOS setting)."
        return $ERROR_WLAN_HARDWARE_DISABLED
    fi

    if [[ "$soft_blocked" == "yes" ]]; then
        echo "Attempting to unblock soft block..."
        sudo rfkill unblock "$rfkill_id"
        sleep 1
        if rfkill list "$rfkill_id" | grep -q "Soft blocked: no"; then
            echo "Wi-Fi successfully unblocked."
        else
            echo "Failed to unblock Wi-Fi."
            return $ERROR_WLAN_SOFT_DISABLED
        fi
    fi

    return 0  # No blocks detected, Wi-Fi is available
}




# Function to check if the Wi-Fi SSID is available
# Param 1: Wi-Fi SSID
# Param 2: Interface name (e.g., wlan0)
# Return: 0 if available, 1 if not available
check_wifi_availability() {
    local wifi_ssid=$1
    local interface=${2:-"wlan0"}  # Default interface to wlan0 if not provided

    # Vérification des paramètres
    if [ -z "$wifi_ssid" ]; then
        echo "Error: SSID parameter is required."
        return 1
    fi

    # Check if the SSID is available on the specified interface
    echo "Scanning for SSID '$wifi_ssid' on interface $interface..."
    if nmcli -t -f SSID dev wifi list ifname "$interface" | grep -Fxq "$wifi_ssid"; then
        echo "SSID '$wifi_ssid' is available on interface $interface."
        return 0  # SSID available
    else
        echo "SSID '$wifi_ssid' is not available on interface $interface."
        return 1  # SSID not available
    fi
}

# Function to check if the interface is connected to the specified SSID
# Param 1: Wi-Fi SSID
# Param 2: Interface name (e.g., wlan0)
# Return: 0 if connected, 1 if not connected
check_wifi_connection() {
    local wifi_ssid=$1
    local interface=${2:-"wlan0"}  # Par défaut, interface = wlan0

    # Vérification des paramètres
    if [ -z "$wifi_ssid" ]; then
        echo "Error: SSID parameter is required."
        return 1
    fi

    # Vérifier si l'interface est connectée au SSID
    echo "Checking if interface '$interface' is connected to SSID '$wifi_ssid'..."
    if sudo iw dev "$interface" link | grep -q "SSID: $wifi_ssid"; then
        echo "Interface '$interface' is connected to SSID '$wifi_ssid'."
        return 0
    else
        echo "Interface '$interface' is not connected to SSID '$wifi_ssid'."
        return 1
    fi
}

# function to create a wifi configuration file
# The function will create a NetworkManager configuration file for the specified Wi-Fi SSID
# and password
# The configuration file will be created in /etc/NetworkManager/system-connections/$SSID.nmconnection
# Param 1: Wi-Fi SSID
# Param 2: Wi-Fi password
# Return: 0 if successful, 1 if failed
create_wifi_config() {
    local SSID="$1"
    local PASSPHRASE="$2"
    local CONFIG_PATH="/etc/NetworkManager/system-connections/$SSID.nmconnection"

    if [[ -z "$SSID" || -z "$PASSPHRASE" ]]; then
        echo "Usage: create_wifi_config <SSID> <PASSPHRASE>"
        return 1
    fi

    if [ -f "$CONFIG_PATH" ]; then
        rm -f "$CONFIG_PATH"
        if [ $? -ne 0 ]; then
            echo "Failed to remove existing configuration file: $CONFIG_PATH"
            return 1
        else
            echo "Existing configuration file removed: $CONFIG_PATH"
        fi
    fi
    sudo bash -c "cat > \"$CONFIG_PATH\" <<EOF
[connection]
id=$SSID
type=wifi
interface-name=wlan0
timestamp=$(date +%s)

[wifi]
mode=infrastructure
ssid=$SSID

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk=$PASSPHRASE

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto
EOF"

    # Set correct file permissions
    sudo chmod 600 "$CONFIG_PATH"
    if [ $? -ne 0 ]; then
        echo "Failed to set permissions for configuration file: $CONFIG_PATH"
        return 1
    fi
    echo "Configuration created: $CONFIG_PATH"
    return 0
}

# Function to connect to a Wi-Fi network
# Param 1: Wi-Fi SSID
# Param 2: Wi-Fi password
# Param 3: Interface name (e.g., wlan0)
# Return: 0 if successful, 1 if failed
connect_to_wifi() {
    local wifi_ssid=$1
    local wifi_password=$2
    local interface=${3:-wlan0}  # Default interface to wlan0 if not provided

    if [ -z "$wifi_ssid" ]; then
        echo "Error: SSID is required parameter."
        return 1
    fi

    echo "Attempting to connect to SSID '$wifi_ssid' on interface '$interface'..."

    # Connexion avec ou sans mot de passe
    if [ -n "$wifi_password" ]; then
        create_wifi_config "$wifi_ssid" "$wifi_password"
        if [ $? -ne 0 ]; then
            echo "Failed to create Wi-Fi configuration for '$wifi_ssid'."
            return 1
        else
            wifi_password=" with password ********"
        fi
    else
        wifi_password=" with no password provided"
    fi

    output=$(nmcli dev wifi connect "$wifi_ssid" ifname "$interface" 2>&1)
    ret=$?
    if [ $ret -eq 0 ]; then
        echo "Successfully connected to '$wifi_ssid' $wifi_password on interface '$interface'."
        return 0
    else
        echo "Failed to connect to '$wifi_ssid' $wifi_password on interface '$interface'."
        echo "Error: $ret - $output"
        return $ret
    fi
}

# Function to reset the Wi-Fi interface
# Param 1: Interface name (e.g., wlan0)
# Return: 0 if successful, 1 if failed
disconnect_from_wifi() {
    local interface=${1:-wlan0}  # Default interface to wlan0 if not provided

    echo "Disconnecting from the Wi-Fi network on interface '$interface'..."
    if nmcli dev disconnect "$interface"; then
        echo "Successfully disconnected from the Wi-Fi network."
        return 0
    else
        echo "Failed to disconnect from the Wi-Fi network."
        return 1
    fi
}

# Function to check if the Hotspot is already active
# Param 1: Interface name (e.g., wlan0)
# Param 2: Hotspot SSID (default: Hotspot)
# Return: 0 if Hotspot is active, 1 if Hotspot is inactive
check_hotspot() {
    local interface=${1:-wlan0}
    local hotspot_ssid=${2:-"Hotspot"}

    
    local type=$(sudo iw dev "$interface" info | awk '/type/ {print $2}')
    local current_ssid=$(sudo iw dev "$interface" info | awk '/ssid/ {print $2}')

    if [ "$type" == "AP" ] && [ "$current_ssid" == "$hotspot_ssid" ]; then
        echo "Hotspot '$hotspot_ssid' is ON on interface $interface."
        return 0
    else
        echo "Hotspot '$hotspot_ssid' is OFF on interface $interface."
        return 1
    fi
}

# Function to start the Hotspot
# The function will start the Hotspot with the specified SSID and password
# Param 1: Interface name (e.g., wlan0)
# Param 2: Hotspot SSID (default: Hotspot)
# Param 3: Hotspot password (default: Hotspot123)
# Param 4: Hotspot connection name (default: Hotspot-con)
# Return: 0 if Hotspot is started successfully, 1 if failed
start_hotspot() {
    local interface=${1:-wlan0}  # Default interface to wlan0 if not provided
    local hotspot_ssid=${2:-"Hotspot"}
    local hotspot_password=${3:-"Hotspot123"}

    check_hotspot "$interface" "$hotspot_ssid"
    if [ $? -eq 0 ]; then
        return 0
    fi
    nmcli device wifi hotspot ssid "$hotspot_ssid" password "$hotspot_password" ifname "$interface" con-name con_"$hotspot_ssid" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to start the Hotspot."
        return 1
    fi
    echo "Hotspot started successfully. SSID: $hotspot_ssid, Password: $hotspot_password"
    return 0
}

# Function to stop the Hotspot if a successful Wi-Fi connection is made
# The function will stop the Hotspot connection and delete the connection profile
# if it exists in NetworkManager
# Param 1: Interface name (e.g., wlan0)
# Param 2: Hotspot SSID (default: Hotspot)
# Return: 0 if Hotspot is stopped successfully, 1 if failed
stop_hotspot() {
    local interface=${1:-"wlan0"}  # Default interface to wlan0 if not provided
    local hotspot_ssid=${2:-"Hotspot"}  # Default connection name

    stopped=0
    check_hotspot "$interface" "$hotspot_ssid";
    if [ $? -eq 0 ]; then
        nmcli connection down "con_$hotspot_ssid"
        if [ $? -ne 0 ]; then
            echo "Failed to stop the Hotspot connection."
            return 1
        fi
        stopped=1
    fi

    # Check if the Hotspot connection is defined in NetworkManager
    cleaned=0
    if nmcli connection show | grep -q "con_$hotspot_ssid"; then
        nmcli connection delete "con_$hotspot_ssid"
        if [ $? -ne 0 ]; then
            echo "Failed to delete the Hotspot connection."
            return 1
        fi
        cleaned=1
    fi
    if [ $stopped -eq 1 ] || [ $cleaned -eq 1 ]; then
        echo "Hotspot stopped and cleaned."
    fi
    return 0
}
