#!/bin/bash

# -------------------------------------------------------------------
# Wi-Fi Connect Script
#
# Script to connect to a Wi-Fi network, create a Hotspot if necessary,
# and handle systemd service installation for the Wi-Fi connection
#
# Description:
# This script checks the availability of a specified Wi-Fi network and
# attempts to connect. If the network is unavailable, it will attempt
# to reset the Wi-Fi interface and create a Hotspot. It can also be 
# installed as a systemd service to run automatically.
#
# Script can handle different command line to achieve its goal.
# Script can handle wifi connection with wrong status and retry to connect.
#
# Version: 1.0.2
# Author: Torayld
# -------------------------------------------------------------------

# Script version
SCRIPT_VERSION="1.0.2"

# Default values if not specified via arguments
interface="wlan0"                           # Wireless interface name
wifi_ssid="YourSSID"                        # Wi-Fi SSID
wifi_password="YourPassword"                # Wi-Fi password
hotspot_ssid="Hotspot"                      # Hotspot SSID
hotspot_password="hotspot123"               # Hotspot password
hotspot_connection_name="HotspotConnection" # Connection name for the Hotspot
max_wait_time=10                            # Maximum wait time in minutes#
check_interval=30                           # SSID check interval in seconds
hotspot_enable=false                        # Enable Hotspot if Wi-Fi is unavailable
hotspot_disable=false                       # Enable Hotspot if Wi-Fi is unavailable
hotspot_start_wait_time=2                   # Wait time to start the Hotspot in minutes

# Print version information
print_version() {
    echo "$0 version $SCRIPT_VERSION"
    exit $ERROR_OK
}

# Function to display help
display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --interface <interface>      Specifies the wireless interface name (default $interface)."
    echo "  -s, --ssid <ssid>                Specifies the Wi-Fi SSID to connect to (default $wifi_ssid)."
    echo "  -p, --password <password>        Specifies the Wi-Fi password (default $wifi_password)."
    echo "  -m, --max-wait-time <minutes>    Specifies the maximum wait time in minutes (default $max_wait_time)."
    echo "  -c, --check-interval <seconds>   Specifies the SSID check interval in seconds (default $check_interval)."
    echo "  -he, --hotspot-enable            Specifies whether to enable the Hotspot if Wi-Fi is unavailable after $hotspot_start_wait_time minutes (default false)."
    echo "  -hs, --hotspot-ssid              Specifies the Hotspot SSID (default $hotspot_ssid)."
    echo "  -hp, --hotspot-password          Specifies the Hotspot password (default $hotspot_password)."
    echo "  -hw, --hotspot-wait              Specifies the Hotspot delay before start 0 to start now (default $hotspot_start_wait_time minutes)."
    echo "  -hd, --hotspot-disable           Specifies whether to disable the Hotspot specified by -hs, --hotspod-ssid <HOTSPOT_SSID>."
    echo "  -si, --systemd-install <param>   Install as a systemd service with a parameter passed to the child script"
    echo "  -sr, --systemd-remove            Removes the systemd service ONLY and exits."
    echo "  -v, --version                    Display the script version"
    echo "  -er, --error                     Display error codes and their meanings."
    echo "  -h, --help                       Display this help message"
    echo ""
}

# Error codes (documenting the exit codes)
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


# Display error codes
display_error_codes() {
    echo "Error Codes and their Meanings:"
    echo "---------------------------------------------------"
    echo " $ERROR_INVALID_OPTION    : Invalid or unknown option provided."
    echo " $ERROR_MISSING_ARGUMENT  : Missing argument for a required option."
    echo " $ERROR_OPTION_CONFLICT   : Conflict between 2 arguments."
    echo " $ERROR_ARGUMENT_WRONG    : Argument value is not valid."
    echo " $ERROR_INVALID_FILE      : The file does not exist or is not valid."
    echo " $ERROR_NOT_EXECUTABLE    : The file is not executable."
    echo " $ERROR_FILE_COPY_FAILED  : The file copy operation failed."
    echo " $ERROR_PERMISSION_FAILED : The chmod operation failed."
    echo " $ERROR_COPY_CANCELED     : The file copy operation canceled."
    echo " $ERROR_FAILED_TO_RESET_INTERFACE : Failed to reset the interface."
    echo "---------------------------------------------------"
}

# Check if an argument is provided
# Usage: check_argument <arg>
# Example: check_argument "$1"
# Returns 0 if an argument is provided, 1 otherwise
check_argument(){
    local arg="$1"

    if [ -z "$arg" ] || [[ "$arg" == -* ]]; then # If no value is provided or the value is another argument (starts with -), use the default pat
        return 1
    else
        return 0
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

    environnement=''
    if [ -n "$interface" ]; then
        environnement+="INTERFACE='$interface' "
    fi
    if [ -n "$wifi_ssid" ]; then
        environnement+="SSID='$wifi_ssid' PWD='$wifi_password' "
    fi
    if [ "$hotspot_enable" = true ]; then
        environnement+="H_SSID='$hotspot_ssid' H_PWD='$hotspot_password' H_TIME='$hotspot_start_wait_time' "
    fi

    if [ "$max_wait_time" = true ]; then
        environnement+="MAX_WAIT='$max_wait_time' "
    fi
    if [ "$check_interval" = true ]; then
        environnement+="CHECK_INTERVAL='$check_interval' "
    fi

    # Calling systemd.sh to install the service
    output=$(./systemd.sh -exe "$0" -cs -csf -n "wifi_hotspot" -env "$environnement" \
        -d "Check WIFI and start Hotspot with Systemd" $param)
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

    # Search for the SSID OR H_SSID value in /etc/systemd/system/wifi_hotspotX.service files
    result=$(grep -rl "SSID='$wifi_ssid'" /etc/systemd/system/wifi_hotspot*.service)
    if [ -n "$result" ]; then
        echo "Found SSID=$wifi_ssid in the following service file(s):"
        echo "$result"
    else
        result=$(grep -rl "H_SSID='$hotspot_ssid'" /etc/systemd/system/wifi_hotspot*.service)
        if [ -n "$result" ]; then
            echo "Found H_SSID=$hotspot_ssid in the following service file(s):"
            echo "$result"
        else
            echo "No service files found with SSID=$wifi_ssid OR H_SSID=$hotspot_ssid"
            exit $ERROR_INVALID_FILE
        fi
    fi

    # Check if the service file exists
    if [ ! -f "./systemd.sh" ]; then
        echo "Error: systemd.sh not found to remove service."
        exit $ERROR_INVALID_FILE
    fi

    # Call the child script to remove the service
    output=$(./systemd.sh -rm $result -env "-hs $hotspot_ssid -hd")
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
    local dns_name_check=${2:-www.google.com}
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

# Function to check if the Wi-Fi SSID is available
# Param 1: Wi-Fi SSID
# Param 2: Interface name (e.g., wlan0)
# Return: 0 if available, 1 if not available
check_wifi_availability() {
    local wifi_ssid=$1
    local interface=${2:-wlan0}  # Default interface to wlan0 if not provided

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
    local interface=${2:-wlan0}  # Par défaut, interface = wlan0

    # Vérification des paramètres
    if [ -z "$wifi_ssid" ]; then
        echo "Error: SSID parameter is required."
        return 1
    fi

    # Vérifier si l'interface est connectée au SSID
    echo "Checking if interface '$interface' is connected to SSID '$wifi_ssid'..."
    if iw dev "$interface" link | grep -q "SSID: $wifi_ssid"; then
        echo "Interface '$interface' is connected to SSID '$wifi_ssid'."
        return 0
    else
        echo "Interface '$interface' is not connected to SSID '$wifi_ssid'."
        return 1
    fi
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
        if nmcli dev wifi connect "$wifi_ssid" password "$wifi_password" ifname "$interface"; then
            echo "Successfully connected to '$wifi_ssid' on interface '$interface'."
            return 0
        else
            echo "Failed to connect to '$wifi_ssid' with the provided password."
            return 1
        fi
    else
        if nmcli dev wifi connect "$wifi_ssid" ifname "$interface"; then
            echo "Successfully connected to '$wifi_ssid' on interface '$interface'."
            return 0
        else
            echo "Failed to connect to '$wifi_ssid'. No password was provided."
            return 1
        fi
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

    existing_hotspot=$(nmcli -t -f name,type,device con show --active | grep "^$hotspot_ssid:802-11-wireless:$interface")

    if [ -n "$existing_hotspot" ]; then
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
    local hotspot_connection_name=${4:-"Hotspot-con"}

    check_hotspot "$interface" "$hotspot_ssid"
    if [ $? -eq 0 ]; then
        return 0
    fi
    nmcli device wifi hotspot ssid "$hotspot_ssid" password "$hotspot_password" ifname "$interface" con-name "$hotspot_connection_name"
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
    local interface=${1:-wlan0}  # Default interface to wlan0 if not provided
    local hotspot_ssid=${2:-"Hotspot"}  # Default connection name

    check_hotspot "$interface" "$hotspot_ssid";
    if [ $? -eq 0 ]; then
        nmcli connection down "$hotspot_ssid"
        if [ $? -ne 0 ]; then
            echo "Failed to stop the Hotspot connection."
            return 1
        fi
    fi

    # Check if the Hotspot connection is defined in NetworkManager
    if nmcli connection show | grep -q "$hotspot_ssid"; then
        nmcli connection delete "$hotspot_ssid"
        if [ $? -ne 0 ]; then
            echo "Failed to delete the Hotspot connection."
            return 1
        fi
    fi
    echo "Hotspot stopped and cleaned."
    return 0
}

# Argument parsing
while [[ "$1" != "" ]]; do
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
        -s|--ssid)
            if ! check_argument "$2"; then
                echo "Error: SSID cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            wifi_ssid="$2"
            shift 2
            ;;
        -p|--password)
            if ! check_argument "$2"; then
                echo "Error: Password cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            wifi_password="$2"
            shift 2
            ;;
        -i|--interface)
            if ! check_argument "$2"; then
                echo "Error: Interface cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            interface="$2"
            shift 2
            ;;
        -m|--max-wait-time)
            if ! check_argument "$2"; then
                echo "Error: Maximum wait time cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            max_wait_time="$2"
            if [ $max_wait_time -lt 0 ]; then
                echo "Error: Maximum wait time cannot be negative."
                exit $ERROR_INVALID_OPTION
            fi
            shift 2
            ;;
        -c|--check-interval)
            if ! check_argument "$2"; then
                echo "Error: Check interval cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            check_interval="$2"
            if [ $check_interval -lt 0 ]; then
                echo "Error: Check interval cannot be negative."
                exit $ERROR_INVALID_OPTION
            fi
            shift 2
            ;;
        -he|--hotspot-enable)
            shift
            hotspot_enable=true
            ;;
        -hs|--hotspot-ssid)
            if ! check_argument "$2"; then
                echo "Error: Hotspot SSID cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            hotspot_ssid="$2"
            shift 2
            ;;
        -hp|--hotspot-password)
            if ! check_argument "$2"; then
                echo "Error: Hotspot password cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            hotspot_password="$2"
            shift 2
            ;;
        -hw|--hotspot-wait)
            if ! check_argument "$2"; then
                echo "Error: Hotspot start wait time cannot be empty."
                exit $ERROR_MISSING_ARGUMENT
            fi
            hotspot_start_wait_time="$2"
            if [ $hotspot_start_wait_time -lt 0 ]; then
                echo "Error: Hotspot start wait time cannot be negative."
                exit $ERROR_INVALID_OPTION
            fi
            shift 2
            ;;
        -hd|--hotspot-disable)
            shift
            hotspot_disable=true
            ;;
        *)
            echo "Invalid option: $1"
            display_help
            exit $ERROR_INVALID_OPTION
            ;;
    esac
done

# If the -rs option is used, remove the systemd service
if [ "$uninstall_systemd" = true ]; then
    remove_systemd_service
fi

# If the -si option is used, install the systemd service
if [ -n "$install_systemd" ]; then
    install_systemd_service
fi

# Check if running from systemd and import environment variables
if [ -n "$INVOCATION_ID" ]; then
    systemctl --user import-environment LABEL PARTUUID SELECTED_PARTITION MOUNT_POINT
    echo "Starting from SystemCTL import environment variable " | sudo tee /dev/kmsg
fi

# Use systemd passed environment variables if available
if [ -n "${INTERFACE}" ]; then
    interface="${INTERFACE}"
fi
if [ -n "${SSID}" ]; then
    wifi_ssid="${SSID}"
    wifi_password="${PWD}"
fi
if [ -n "${H_SSID}" ]; then
    hotspot_enable=true
    hotspot_ssid="${H_SSID}"
    hotspot_password="${H_PWD}"
    hotspot_start_wait_time="${H_TIME}"
fi
if [ -n "${MAX_WAIT}" ]; then
    max_wait_time="${MAX_WAIT}"
fi
if [ -n "${CHECK_INTERVAL}" ]; then
    check_interval="${CHECK_INTERVAL}"
fi

# Check if the Wi-Fi interface is valid wifi interface
if ! nmcli device status | grep -q "^$interface.*wifi"; then
    echo "Error: Interface $interface is not a valid Wi-Fi interface or is not available."
    exit $ERROR_INVALID_OPTION
fi

if [ $hotspot_start_wait_time -gt $max_wait_time ]; then
    echo "Error: Hotspot start wait time cannot be greater than the maximum wait time."
    exit $ERROR_INVALID_OPTION
fi

if [ "$hotspot_disable" = true ]; then
    stop_hotspot "$interface" "$hotspot_ssid"
    exit $ERROR_OK
fi

# Loop to check Wi-Fi availability at regular intervals
elapsed_time=0  # Elapsed time in seconds
connected=false # Flag to check if the device is connected to the network

while [ $elapsed_time -lt $((max_wait_time * 60)) ]; do
    if check_interface "$interface"; then
        if get_ip_assigned "$interface"; then
            if check_ping "$interface" "$return_ip_gateway_addr"; then #Test if ping is ok to check connectivity
                connected=true
            elif get_dns_available "$interface"; then #Test if DNS is ok to check connectivity if ping is not allowed
                connected=true
            fi
       fi
    fi

    if [ "$connected" = true ]; then
        stop_hotspot "$interface" "$hotspot_ssid"
        exit $ERROR_OK
    else
        if [ -n "$wifi_ssid" ]; then
            if check_wifi_availability "$wifi_ssid" "$interface"; then
                if check_wifi_connection "$wifi_ssid" "$interface"; then # Wifi says but no IP nor DNS
                    disconnect_from_wifi "$interface"
                    sleep 10
                fi
                if connect_to_wifi "$wifi_ssid" "$wifi_password" "$interface"; then
                    stop_hotspot "$interface" "$hotspot_ssid"
                    exit $ERROR_OK
                fi
            fi
        fi
        if [ $elapsed_time -ge $((hotspot_start_wait_time * 60)) ] && [ "$hotspot_enable" = true ]; then
            start_hotspot "$interface" "$hotspot_ssid" "$hotspot_password"
        else
            if ! check_interface "$interface" "1" "true"; then
                exit $ERROR_FAILED_TO_RESET_INTERFACE
            fi
        fi
    fi

    echo "Waiting for $check_interval seconds before the next check..."
    sleep $check_interval
    elapsed_time=$((elapsed_time + check_interval))
    echo "Elapsed time: $elapsed_time seconds"
done

exit $ERROR_OK