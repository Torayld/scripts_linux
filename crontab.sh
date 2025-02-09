#!/bin/bash

# -------------------------------------------------------------------
# Crontab manager
#
# Version: 1.0.0
# Author: Torayld
# -------------------------------------------------------------------

# Script version
SCRIPT_VERSION="1.0.0"

# Default values
NAME="my_cron_jobs"
MIN="0"
HOUR="0"
DOM="*"
MON="*"
DOW="*"
USER="$(whoami)"
LOG_FILE=""
SCRIPT_PATH="/usr/local/bin"
FORCE_REPLACE=false
REMOVE_SCRIPT=false
APPEND=false
USER_FOLDER=false

# Valid months and days
VALID_MONTHS="jan feb mar apr may jun jul aug sep oct nov dec"
VALID_DAYS="mon tue wed thu fri sat sun"

# Print version information
print_version() {
    echo "$0 version $SCRIPT_VERSION"
    exit $ERROR_OK
}

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name <value>             Name of the cron job."
    echo "  -m, --minute <value>           Minute (0-59) when the command should run. Default: $DEFAULT_MIN"
    echo "  -h, --hour <value>             Hour (0-23) when the command should run. Default: $DEFAULT_HOUR"
    echo "  -dom, --day-of-month <value>   Day of the month (1-31) when the command should run. Default: $DEFAULT_DOM"
    echo "  -mon, --month <value>          Month (jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec) when the command should run. Default: $DEFAULT_MON"
    echo "  -dow, --day-of-week <value>    Day of the week (mon, tue, wed, thu, fri, sat, sun) when the command should run. Default: $DEFAULT_DOW"
    echo "  -u, --user <value>             User that the command should run as. Default: $DEFAULT_USER"
    echo "  -s, --script <value>           Script or command to run."
    echo "  -cs, --copy-script [path]      Specifies the path of the script to copy (default $script_path_default)."
    echo "  -csf, --copy-script-force      Force overwrite the script file without confirmation."
    echo "  -l, --log <value>              Log file where the output of the command should be redirected."
    echo "  -a, --append                   Append job to named cron job"
    echo "  -u, --user                     Use user cron folder include --append"
    echo "  -v, --version                  Show script version."
    echo "  -er, --error                   Display error codes and their meanings."
    echo "  -h, --help                     Display this help."
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
    echo "---------------------------------------------------"
}

# Check if an argument is provided
# Usage: check_argument "$1" [int|str|intalpha] by default alphanum
# Example: check_argument "98" "int" returns 0
# Example: check_argument "98" "str" returns 1
# Example: check_argument "alpha" "int" returns 1
# Example: check_argument "alpha" "str" returns 0
# Returns 0 if an argument is provided, 1 otherwise
check_argument(){
    local arg="$1"
    local arg_type=${2:-"alphanum"}

    if [[ "$arg_type" != 'int' && "$arg_type" != 'str' && "$arg_type" != 'alphanum' ]]; then
        echo "Error: Invalid argument type. Must be 'int' or 'str'."
        return 1
    fi

    if [ -z "$arg" ] || [[ "$arg" == -* ]]; then # If no value is provided or the value is another argument (starts with -), use the default pat
        return 1
    else
        if [[ "$arg_type" == 'int' ]] && ! [[ "$arg" =~ ^[0-9]+$ ]]; then
            return 1
        elif [[ "$arg_type" == 'str' ]] && ! [[ "$arg" =~ ^[a-zA-Z]+$ ]]; then
            return 1
        fi
        return 0
    fi
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

# Check if the user has permission to use cron
# Usage: check_cron_permission "$1"
# Example: check_cron_permission "user_unknown"
# Returns 0 if the user has permission to use cron, 1 otherwise
check_cron_permission() {
    local user="$1"

    if [ -f /etc/cron.allow ]; then
        if grep -q "^$user$" /etc/cron.allow; then
            echo "The user is allowed to use cron."
        else
            echo "The user is not in cron.allow."
            return 1
        fi
    elif [ -f /etc/cron.deny ]; then
        if grep -q "^$user$" /etc/cron.deny; then
            echo "The user is denied by cron.deny."
            return 1
        else
            echo "The user is not in cron.deny, they can use cron."
        fi
    else
        echo "Neither cron.allow nor cron.deny files exist, the user can probably use cron."
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

# Function to check if a specific user can write to a file
# Usage: check_user_write_to_file "$1" "$2"
# Example: check_user_write_to_file "user_unknown" "/path/to/file"
# Returns 0 if the user can write to the file, 1 otherwise
check_user_write_to_file() {
    local user="$1"
    local file="$2"

    # Check if the file exists
    if [[ ! -e "$file" ]]; then
        echo "The file does not exist."
        return 1
    fi

    # Check if the file is writable by the specified user
    if sudo -u "$user" test -w "$file"; then
        echo "User '$user' can write to the file."
        return 0
    else
        echo "User '$user' cannot write to the file."
        return 1
    fi
}

source functions/copy_file.sh

# Argument parsing
while [[ $# -gt 0 ]]; do
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
        -n|--name)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                NAME="$2"
                shift 2
            fi
            ;;
        -m|--minute)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "$2" =~ ^([0-5]?[0-9])$|^([0-5]?[0-9]-[0-5]?[0-9])$|^(\*/[1-9][0-9]*)$|^([0-5]?[0-9](,[0-5]?[0-9])*)$ ]]; then
                exit $ERROR_INVALID_OPTION
            else
                MIN="$2"
                shift 2
            fi
            ;;
        -h|--hour)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "$2" =~ ^([0-2]?[0-3])$|^([0-2]?[0-3]-[0-2]?[0-3])$|^(\*/[1-9][0-3]*)$|^([0-2]?[0-3](,[0-2]?[0-3])*)$ ]]; then
                exit $ERROR_INVALID_OPTION
            else
                HOUR="$2"
                shift 2
            fi
            ;;
        -dom|--day-of-month)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "$2" =~ ^([1-9]|[12][0-9]|3[01])$|^([1-9]|[12][0-9]|3[01])-([1-9]|[12][0-9]|3[01])$|^(\*/[1-9][0-9]*)$|^([1-9]|[12][0-9]|3[01])(,([1-9]|[12][0-9]|3[01]))*$ ]]; then
                exit $ERROR_INVALID_OPTION
            else
                DOM="$2"
                shift 2
            fi
            ;;
        -mon|--month)
            if ! check_argument "$2" "str"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            #elif [[ ! "$VALID_MONTHS" =~ (^|[[:space:]])"$2"($|[[:space:]]) ]] && ! [[ "$2" =~ ^[0-9\*/,-]+$ ]]; then
            elif ! [[ "$2" =~ ^(0?[1-9]|1[0-2])$|^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)$|^([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)-([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)$|^(\*/[1-9][0-9]*)$|^([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)(,([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec))*$ ]]; then
                echo "Error: Invalid month format."
                exit $ERROR_INVALID_OPTION
            else
               MON="$2"
               shift 2
            fi
            ;;
        -dow|--day-of-week)
            if ! check_argument "$2" "str"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "$2" =~ ^([1-7])$|^(mon|tue|wed|thu|fri|sat|sun)$|^([1-7])-([1-7])$|^(\*/[1-9][0-9]*)$|^([1-7]|mon|tue|wed|thu|fri|sat|sun)(,([1-7]|mon|tue|wed|thu|fri|sat|sun))*$ ]]; then
            #elif [[ ! "$VALID_DAYS" =~ (^|[[:space:]])"$DOW"($|[[:space:]]) ]] && ! [[ "$DOW" =~ ^[0-9\*/,-]+$ ]]; then
                echo "Error: Invalid day format."
                exit 1
            else
                DOW="$2"
                shift 2
            fi
            ;;
        -u|--user)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            fi
            USER="$2"
            shift 2
            if ! check_user "$USER"; then
                exit $ERROR_ARGUMENT_WRONG
            fi

            if ! check_cron_permission "$USER"; then
                exit $ERROR_ARGUMENT_WRONG
            fi
            ;;
        -s|--script)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            fi
            SCRIPT="$2"
            shift 2
            if ! check_user_script_permission "$SCRIPT" "$USER"; then
                exit $ERROR_ARGUMENT_WRONG
            fi
            ;;
        -cs|--copy-script)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            fi
            # If a value is provided, assign it to script_path
            SCRIPT_PATH="$2"
            shift 2
            ;;
        -csf|--copy-script-force)
            FORCE_REPLACE=true
            shift 1
            ;;
        -a|--append)
            APPEND=true
            shift 1
            ;;
        -u|--user)
            USER_FOLDER=true
            shift 1
            ;;
        -l|--log)
            if ! check_argument "$2"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            fi
            LOG_FILE="$2"
            shift 2
            if ! check_user_write_to_file "$USER" "$LOG_FILE"; then
                exit $ERROR_ARGUMENT_WRONG
            fi
            ;;
        *)
            echo "Unknown option: $1"
            exit $ERROR_INVALID_OPTION
            ;;
    esac
done

if [ -z "$SCRIPT" ]; then
    echo "Error: Missing script or command to run."
    display_help
    exit $ERROR_MISSING_ARGUMENT
fi

# Call the function to verify and copy the script
if [ -n "$SCRIPT_PATH" ]; then
    echo "Copying $SCRIPT to $SCRIPT_PATH"
    copy_file "$SCRIPT" "$SCRIPT_PATH"
    return=$?
    if [ $return -ne $ERROR_OK ]; then
        exit $return
    fi
    SCRIPT=$copy_file_return
    echo "Final Script path : $SCRIPT"
fi

# Selecting destination folder for cron
if [ "$USER_FOLDER" = false ]; then
    CRON_PATH='/etc/cron.d/'$USER'_'$NAME
    CRON_EXEMPLE="# *  *  *  *  *  user command to be executed"
    CRON_EXE="$MIN $HOUR $DOM $MON $DOW $USER $SCRIPT $LOG_FILE"
else
    CRON_PATH="/var/spool/cron/crontabs/$USER"
    CRON_EXEMPLE="# *  *  *  *  *  command to be executed"
    CRON_EXE="$MIN $HOUR $DOM $MON $DOW $SCRIPT $LOG_FILE"
    APPEND=true
fi

# if not append, make sure to have to not override file
if [ "$APPEND" = false ]; then
    echo "Creating Job name $NAME into $CRON_PATH"
    tmpfile=$(mktemp)
    echo '.' > $tempfile
    copy_file "$tmpfile" "${CRON_PATH%/}/$NAME"
    return=$?
    if [ $return -ne $ERROR_OK ]; then
        exit $return
    fi
    CRON_PATH=$copy_file_return
    echo "Job name : $NAME created into $CRON_PATH"
    rm "$tmpfile"
    rm "$CRON_PATH"
else

fi

# Creating Header if not exist
if ! [ -f $CRON_PATH ]; then
    echo "# Example of job definition:" >> $CRON_PATH
    echo "# .---------------- minute (0 - 59)"  >> $CRON_PATH
    echo "# |  .------------- hour (0 - 23)" >> $CRON_PATH
    echo "# |  |  .---------- day of month (1 - 31)" > $CRON_PATH
    echo "# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ..." >> $CRON_PATH
    echo "# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat" >> $CRON_PATH
    echo "# |  |  |  |  |" >> $CRON_PATH
    echo "$CRON_EXEMPLE" >> $CRON_PATH
fi

echo "$CRON_EXE" >> $CRON_PATH
echo "Crontab entry added successfully."