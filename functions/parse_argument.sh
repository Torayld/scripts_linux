#!/bin/bash
# -------------------------------------------------------------------
# Split arguments into an array
# Version: 1.0.0
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="1.0.0"

# Example usage
#input='-arg1 -arg2 "value 2" --arg3=value3 --arg4="value 4" -arg5="value d\'espace \"cool\"" -arg "value d\'espace \"Ab\""'
#declare -a args
#declare -a valid_keys=("-arg1" "-arg2" "--arg3" "--arg4" "--flag" "-arg5" "-arg")
#
#input="$*"

# Call the function
#split_arguments "$input" args valid_keys

# Print the extracted arguments
#echo "Extracted arguments:"
#for arg in "${args[@]}"; do
#    echo "$arg"
#done

# Function to split a string of arguments into an array
split_arguments() {
    local input="$1"
    local -n output_array=$2 # Reference to the output array
    local -n keys=$3         # Reference to the list of valid keys

    while [[ -n "$input" ]]; do
        # Case 1: Match arguments with attached values (e.g., -arg=value or --arg=value)
        if [[ "$input" =~ ^(--?[a-zA-Z0-9-]+)=\ *([^\" ]+|\"[^\"]*(\"[^\"]*\")*[^\"]*\") ]]; then
            local arg="${BASH_REMATCH[1]}" # Extract argument name
            local value="${BASH_REMATCH[2]}" # Extract value
            local match="${BASH_REMATCH[0]}" # Full match
            value="${value%\"}" # Remove trailing quote if value is quoted
            value="${value#\"}" # Remove leading quote if value is quoted
            output_array+=("$arg=$value")
            input="${input:${#match}}" # Remove the matched part
            input="${input#"${input%%[! ]*}"}"    # Trim leading spaces

        # Case 2: Match arguments with separate values (e.g., -arg value or --arg value)
        elif [[ "$input" =~ ^(--?[a-zA-Z0-9-]+)\ +(\"[^\"]*\"|[^ -][^ ]*|\"[^\"]*(\"[^\"]*\")*[^\"]*\") ]]; then
            local arg="${BASH_REMATCH[1]}" # Extract argument name
            local value="${BASH_REMATCH[2]}" # Extract value
            local match="${BASH_REMATCH[0]}" # Full match
            value="${value%\"}" # Remove trailing quote if value is quoted
            value="${value#\"}" # Remove leading quote if value is quoted
            if [[ ! " ${keys[*]} " =~ " ${arg} " ]]; then
                echo "Error: Invalid argument key '$arg'"
                return 1
            fi
            output_array+=("$arg=$value")
            input="${input:${#match}}" # Remove the matched part
            input="${input#"${input%%[! ]*}"}"    # Trim leading spaces

        # Case 3: Match standalone flags (e.g., -arg1, --flag)
        elif [[ "$input" =~ ^(--?[a-zA-Z0-9-]+) ]]; then
            local arg="${BASH_REMATCH[1]}" # Extract argument name
            local match="${BASH_REMATCH[0]}" # Full match
            # Validate the key
            if [[ ! " ${keys[*]} " =~ " ${arg} " ]]; then
                echo "Error: Invalid argument key '$arg'"
                return 1
            fi
            output_array+=("$arg")
            input="${input:${#match}}" # Remove the matched part
            input="${input#"${input%%[! ]*}"}"    # Trim leading spaces

        # Error: Invalid format
        else
            echo "Error: Invalid argument format in $input"
            return 1
        fi
    done
}