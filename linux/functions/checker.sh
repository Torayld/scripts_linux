#!/bin/bash
# -------------------------------------------------------------------
# Checkers for arguments, users, and permissions
# Version: 1.0.2
# Author: Torayld
# -------------------------------------------------------------------

# Check if an argument is provided
# Usage: check_argument "$1" [int|str|bool|all] by default all
# Example: check_argument "98" "int" returns 0
# Example: check_argument "98" "str" returns 1
# Example: check_argument "alpha" "int" returns 1
# Example: check_argument "alpha" "str" returns 0
# Returns 0 if an argument is provided, 1 otherwise
check_argument() {
    local arg="${1#*=}"   # Extract the value after '='
    local arg_type=${2:-"all"}  # Default type is "all"

    # Check if the argument type is valid
    if [[ "$arg_type" != 'int' && "$arg_type" != 'str' && "$arg_type" != 'bool' && "$arg_type" != 'all' ]]; then
        echo "Error: Invalid argument type. Must be 'int', 'str', bool or 'all'."
        return 1
    fi

    # Handle empty values
    if [ -z "$arg" ]; then
        return 1  # Reject empty values
    fi

    # Validate the argument format based on the type
    case "$arg_type" in
        int) 
            if ! [[ "$arg" =~ ^[-0-9]+$ ]]; then
                echo "Value must be an integer"
                return 1
            fi
            ;;
        str) 
            if ! [[ "$arg" =~ ^[a-zA-Z]+$ ]]; then
                echo "Value must be a string"
                return 1 
            fi
            ;;
        bool)
            if ! [[ "$arg" =~ ^(true|false)$ ]]; then
                echo "Value must be a boolean (true/false)"
                return 1
            fi
            ;;
    esac

    return 0
}

# Check if user exists
# Usage: check_user "$1"
# Example: check_user "user_unknown"
# Returns 0 if the user exists, 1 otherwise 
check_user() {
    local user="$1"
    if ! id "$user" &>/dev/null; then
        echo "Error: User $user does not exist."
        return 1
    fi

    return 0
}

# Check if the user has permission to execute the script
# Usage: check_user_script_permission "$1" "$2"
# Example: check_user_script_permission "/path/to/script.sh" "user_unknown"
# Returns 0 if the user has permission to execute the script, 1 otherwise
check_user_script_permission() {
    local script_path=$1
    local username=$2

    # Check if the script file exists
    if [ ! -f "$script_path" ]; then
        echo "The script file does not exist."
        return 1
    fi

    # Get the file's owner and group
    script_owner=$(stat -c "%U" "$script_path")
    script_group=$(stat -c "%G" "$script_path")

    # Check if the user is the owner
    if [ "$username" == "$script_owner" ]; then
        if [ "$(stat -c "%A" "$script_path" | cut -b 2)" == "x" ]; then
            echo "The user $username is the owner and can execute the script."
            return 0
        else
            echo "The user $username is the owner but cannot execute the script."
        fi
    # Check if the user belongs to the same group
    elif groups "$username" | grep -qw "$script_group"; then
        if [ "$(stat -c "%A" "$script_path" | cut -b 5)" == "x" ]; then
            echo "The user $username belongs to the same group and can execute the script."
            return 0
        else
            echo "The user $username belongs to the same group but cannot execute the script."
        fi
    # Check if the user has 'others' permission
    elif [ "$(stat -c "%A" "$script_path" | cut -b 8)" == "x" ]; then
        echo "The user $username is neither the owner nor in the same group but can execute the script as others."
        return 0
    else
        echo "The user $username cannot execute the script."
        return 1
    fi
}

# Function to check if a specific user can read a file
# Usage: check_user_read_from_file "$1" "$2"
# Example: check_user_read_from_file "user_unknown" "/path/to/file"
# Returns 0 if the user can read the file, 1 otherwise
check_user_read_from_file() {
    local user="$1"
    local file="$2"

    # Check if the file exists
    if [[ ! -e "$file" ]]; then
        echo "The file does not exist."
        return 1
    fi

    # Check if the file is readable by the specified user
    if sudo -u "$user" test -r "$file"; then
        echo "User '$user' can read the file."
        return 0
    else
        echo "User '$user' cannot read the file."
        return 1
    fi
}

# Function to check if a specific user can write to a file
# Usage: check_user_write_to_file "$1" "$2"
# Example: check_user_write_to_file "user_unknown" "/path/to/file"
# Returns 0 if the user can write to the file, 1 otherwise
check_user_write_to_file() {
    local user="$1"
    local file="$2"

    # Check if the file exists
    if [[ -e "$file" ]]; then
        # File exists, check if writable
        if sudo -u "$user" test -w "$file"; then
            return 0
        else
            echo "User '$user' cannot write to the existing file."
            return 1
        fi
    else
        # File does not exist — check if user can write in the parent directory
        local parent_dir
        parent_dir=$(dirname "$file")

        if sudo -u "$user" test -w "$parent_dir"; then
            return 0
        else
            echo "User '$user' cannot write to the parent directory — cannot create the file."
            return 1
        fi
    fi
}

# Function to check if a port is available
# Usage: check_listen_port "$1"
# Example: check_listen_port "80"
# Returns 0 if the port is free, 1 otherwise
check_listen_port() {
    local port=$1

    if ss -tulnp | grep -q ":$port "; then
        echo "Port $port is busy."
        return 1 
    else
        echo "Port $port is free."
        return 0 
    fi
}