#!/bin/bash
# -------------------------------------------------------------------
# Manage IPv6 enable/disable settings on your Linux system
# Version: 1.0.0
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="1.0.0"
SYSCTL_FILE="/etc/sysctl.conf"

# Print version information
print_version() {
    echo "$0 version $SCRIPT_VERSION"
    exit 0
}

# Print help message
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Manage IPv6 enable/disable settings on your Linux system by modifying /etc/sysctl.conf."
    echo
    echo "Options:"
    echo "  -e, --enable     Enable IPv6"
    echo "  -d, --disable    Disable IPv6"
    echo "  -b, --backup     Create a backup of a specified file or sysctl.conf by default"
    echo "  -h, --help       Display this help message"
    echo "  -v, --version    Show version information"
    echo
    echo "Disclaimer: This script modifies /etc/sysctl.conf and applies changes using 'sysctl -p'."
    echo "            Use with caution as incorrect configurations may impact your network setup."
    exit 0
}

# Error codes (documenting the exit codes)
ERROR_OK=0              # OK
ERROR_INVALID_ARGS=1    # Invalid arguments
ERROR_INVALID_OPTION=10  # Invalid or unknown option provided
ERROR_MISSING_ARGUMENT=11  # Missing argument for a required option
ERROR_OPTION_CONFLICT=12  # Conflict between 2 arguments
ERROR_INVALID_FILE=20    # The file does not exist or is not valid

# Display error codes
display_error_codes() {
    echo "Error Codes and their Meanings:"
    echo "---------------------------------------------------"
    echo " $ERROR_INVALID_OPTION    : Invalid or unknown option provided."
    echo " $ERROR_MISSING_ARGUMENT  : Missing argument for a required option."
    echo " $ERROR_OPTION_CONFLICT   : Conflict between 2 arguments."
    echo " $ERROR_INVALID_FILE      : The file does not exist or is not valid."
    echo "---------------------------------------------------"
}

source functions/update_file.sh

# Enable or disable IPv6 based on the action
manage_ipv6() {
    local action=$1
    local backup=$2

    if [[ $action != "enable" && $action != "disable" ]]; then
        echo "Error: Invalid action specified. Use -e/--enable or -d/--disable."
        print_help
    fi

    # Define the desired value based on action
    local value=0
    if [[ $action == "disable" ]]; then
        value=1
    fi

    # Prepare the key-value pairs to update in sysctl.conf
    local key_value_pairs=("net.ipv6.conf.all.disable_ipv6=$value" 
                           "net.ipv6.conf.default.disable_ipv6=$value"
                           "net.ipv6.conf.lo.disable_ipv6=$value")

    # Call the function to update and compare the sysctl.conf file
    if update_file "$SYSCTL_FILE" key_value_pairs[@] "$backup"; then
        # Apply the changes (if any)
        echo "Applying sysctl changes..."
        sudo sysctl -p
        echo "IPv6 has been ${action}d successfully."
    fi
}

# Main logic to handle arguments
backup_enabled=false
if [[ $# -eq 0 ]]; then
    print_help
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--enable)
            action="enable"
            shift
            ;;
        -d|--disable)
            action="disable"
            shift
            ;;
        -b|--backup)
            backup_enabled=true
            shift
            ;;
        -h|--help)
            print_help
            ;;
        -v|--version)
            print_version
            ;;
        *)
            echo "Error: Unknown option $1"
            print_help
            ;;
    esac
done

# Perform the action if specified
if [[ -n $action ]]; then
    manage_ipv6 "$action" "$backup_enabled"
else
    echo "Error: No action specified. Use -e/--enable or -d/--disable."
    print_help
fi
