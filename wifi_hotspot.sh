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
# Version: 1.0.3
# Author: Torayld
# -------------------------------------------------------------------

# Script version
SCRIPT_VERSION="1.0.3"

# Default values if not specified via arguments
interface="wlan0"                           # Wireless interface name
wifi_ssid="YourSSID"                        # Wi-Fi SSID
wifi_password=""                            # Wi-Fi password
wifi_password_default="YourPassword"        # Default Wi-Fi password
hotspot_ssid="Hotspot"                      # Hotspot SSID
hotspot_password="hotspot123"               # Hotspot password
max_wait_time=10                            # Maximum wait time in minutes#
check_interval=30                           # SSID check interval in seconds
hotspot_enable=false                        # Enable Hotspot if Wi-Fi is unavailable
hotspot_disable=false                       # Enable Hotspot if Wi-Fi is unavailable
hotspot_start_wait_time=2                   # Wait time to start the Hotspot in minutes


script_path="$(cd "$(dirname "$0")" && pwd)"
source $script_path/functions/errors_code.sh
source $script_path/functions/checker.sh
source $script_path/functions/network.sh

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
    echo "  -i, --interface=<interface>        Specifies the wireless interface name (default $interface)."
    echo "  -s, --ssid=<ssid>                  Specifies the Wi-Fi SSID to connect to (default $wifi_ssid)."
    echo "  -p, --password=<password>          Specifies the Wi-Fi password."
    echo "  -m, --max-wait-time=<minutes>      Specifies the maximum wait time in minutes (default $max_wait_time)."
    echo "  -c, --check-interval=<seconds>     Specifies the SSID check interval in seconds (default $check_interval)."
    echo "  -he, --hotspot-enable              Specifies whether to enable the Hotspot if Wi-Fi is unavailable after $hotspot_start_wait_time minutes (default false)."
    echo "  -hs, --hotspot-ssid=<ssid>         Specifies the Hotspot SSID (default $hotspot_ssid)."
    echo "  -hp, --hotspot-password=<password> Specifies the Hotspot password (default $hotspot_password)."
    echo "  -hw, --hotspot-wait=<time>         Specifies the Hotspot delay before start 0 to start now (default $hotspot_start_wait_time minutes)."
    echo "  -hd, --hotspot-disable             Specifies whether to disable the Hotspot specified by -hs, --hotspod-ssid <HOTSPOT_SSID>."
    echo "  -si, --systemd-install=<param>     Install as a systemd service with a parameter passed to the child script"
    echo "  -sr, --systemd-remove              Removes the systemd service ONLY and exits."
    echo "  -ci, --cron-install=<param>        Install as a cron job with a parameter passed to the child script"
    echo "  -cr, --cron-remove                 Removes the cron job ONLY and exits."
    echo "  -v, --version                      Display the script version"
    echo "  -er, --error                       Display error codes and their meanings."
    echo "  -h, --help                         Display this help message"
    echo ""
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
    output=$(./systemd.sh -exe="$0" -cs -csf -n="wifi_hotspot" -env="$environnement" \
        -d="Check WIFI and start Hotspot with Systemd" $param)
    exit_code=${PIPESTATUS[0]} #Capture exit code

    if [ $exit_code -eq $ERROR_OK ]; then
        echo "Systemd service installed successfully. $output"
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
    if [ $exit_code -eq $ERROR_OK ]; then
        echo "Systemd service was removed."
        exit $ERROR_OK
    else
        echo "systemd.sh encountered an error : "$output
        exit $exit_code
    fi
}

# Function to install the systemd service
install_cron() {
    if [ ! -f "./crontab.sh" ]; then
        echo "Error: crontab.sh not found to add cron job."
        exit $ERROR_INVALID_FILE
    fi

    echo "Installing crontab with parameter..."

    param=""
    if [[ -n "$install_cron" && "$install_cron" != "true" ]]; then
        param=$install_cron
    fi

    script_param=''
    if [ -n "$interface" ]; then
        script_param+="-i='$interface' "
    fi
    if [ -n "$wifi_ssid" ]; then
        script_param+="-s='$wifi_ssid' -p='$wifi_password' "
    fi
    if [ "$hotspot_enable" = true ]; then
        script_param+="-he -hs='$hotspot_ssid' -hp='$hotspot_password' -hw='$hotspot_start_wait_time' "
    fi

    if [ "$max_wait_time" = true ]; then
        script_param+="-m='$max_wait_time' "
    fi
    if [ "$check_interval" = true ]; then
        script_param+="-c='$check_interval' "
    fi

    # Calling crontab.sh to install the service
    output=$(./crontab.sh -cs -csf -n="wifi_hotspot" -exe="$0" --exe-param="$script_param" $param)
    exit_code=${PIPESTATUS[0]} #Capture exit code

    if [ $exit_code -eq $ERROR_OK ]; then
        echo "Crontab installed successfully."
        exit $ERROR_OK
    else
        echo "Error installing crontab : $output"
        exit $exit_code
    fi
}

# Function to remove the systemd service
remove_cron() {

    # Search for the SSID OR H_SSID value in /etc/systemd/system/wifi_hotspotX.service files
    result=$(grep -rl "-s='$wifi_ssid'" /etc/cron.d/*wifi_hotspot*)
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
    if [ ! -f "./crontab.sh" ]; then
        echo "Error: crontab.sh not found to remove service."
        exit $ERROR_INVALID_FILE
    fi

    # Call the child script to remove the service
    output=$(./crontab.sh -rm $result -env "-hs $hotspot_ssid -hd")
    exit_code=${PIPESTATUS[0]} #Capture exit code

    # Check the exit status of the child script
    if [ $exit_code -eq $ERROR_OK ]; then
        echo "Cron job was removed."
        exit $ERROR_OK
    else
        echo "crontab.sh encountered an error : "$output
        exit $exit_code
    fi
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
        -si=*|--systemd-install=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                install_systemd="${1#*=}"
                shift
            fi
            ;;
        -si|--systemd-install)
            install_systemd=true
            shift
            ;;
        -sr|--systemd-remove)
            uninstall_systemd=true
            shift
            ;;
        -ci=*|--cron-install=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                install_cron="${1#*=}"
                shift
            fi
            ;;
        -ci|--cron-install)
            install_cron=true
            shift
            ;;
        -cr|--cron-remove)
            uninstall_cron=true
            shift
            ;;
        -s=*|--ssid=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                wifi_ssid="${1#*=}"
                shift
            fi
            ;;
        -p=*|--password=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                wifi_password="${1#*=}"
                shift
            fi
            ;;
        -i=*|--interface=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                interface="${1#*=}"
                shift
            fi
            ;;
        -m=*|--max-wait-time=*)
            if ! check_argument "$1" "int"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                max_wait_time="${1#*=}"
                shift
                if [ $max_wait_time -lt 0 ]; then
                    echo "Error: Maximum wait time cannot be negative."
                    exit $ERROR_INVALID_OPTION
                fi
            fi
            ;;
        -c=*|--check-interval=*)
            if ! check_argument "$1" "int"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                check_interval="${1#*=}"
                shift
                if [ $check_interval -lt 0 ]; then
                    echo "Error: Check interval cannot be negative."
                    exit $ERROR_INVALID_OPTION
                fi
            fi
            ;;
        -he|--hotspot-enable)
            hotspot_enable=true
            shift
            ;;
        -hs=*|--hotspot-ssid=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                hotspot_ssid="${1#*=}"
                shift
            fi
            ;;
        -hp=*|--hotspot-password=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                hotspot_password="${1#*=}"
                shift
            fi
            ;;
        -hw=*|--hotspot-wait=*)
            if ! check_argument "$1" "int"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                hotspot_start_wait_time="${1#*=}"
                shift
                if [ $hotspot_start_wait_time -lt 0 ]; then
                    echo "Error: Hotspot start wait time cannot be negative."
                    exit $ERROR_INVALID_OPTION
                fi
            fi
            ;;
        -hd|--hotspot-disable)
            hotspot_disable=true
            shift
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

if [ "$uninstall_cron" = true ]; then
    remove_cron
fi

if [ -n "$install_cron" ]; then
    install_cron
fi

# Check if running from systemd and import environment variables
if [ -n "$INVOCATION_ID" ]; then
    systemctl --user import-environment LABEL PARTUUID SELECTED_PARTITION MOUNT_POINT
    echo "Starting from SystemCTL import environment variable " | sudo tee /dev/kmsg
fi

if [[ -n "$CRON_TZ" ]]; then
    echo "Starting from Cron"
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
            if check_wifi_connection "$wifi_ssid" "$interface"; then # Wifi says but no IP nor DNS
                if check_ping "$interface" "$return_ip_gateway_addr"; then #Test if ping is ok to check connectivity
                    connected=true
                elif get_dns_available "$interface"; then #Test if DNS is ok to check connectivity if ping is not allowed
                    connected=true
                fi
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
                connect_to_wifi "$wifi_ssid" "$wifi_password" "$interface"
                ret=$?
                if [ $ret -eq 0 ]; then
                    stop_hotspot "$interface" "$hotspot_ssid"
                    exit $ERROR_OK
                elif [ $ret -eq 4 ]; then
                    echo "Password Failed"
                    if [ "$hotspot_enable" = true ]; then #if password failed and hotspot is enabled, start hostpost with nowait and exit to have stable hotspot connection
                        start_hotspot "$interface" "$hotspot_ssid" "$hotspot_password"
                        exit $ERROR_ARGUMENT_WRONG
                    fi
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