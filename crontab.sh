#!/bin/bash

# -------------------------------------------------------------------
# Crontab manager
#
# Version: 1.0.1
# Author: Torayld
# -------------------------------------------------------------------

# Script version
SCRIPT_VERSION="1.0.1"

# Default values
NAME="my_cron_jobs"
MIN="*"
HOUR="*"
DOM="*"
MON="*"
DOW="*"
USER="$(whoami)"
LOG_FILE=""
script_path_default="/usr/local/bin"
FORCE_REPLACE=false
REMOVE_SCRIPT=false
APPEND=false
USER_FOLDER=false

# Valid months and days
VALID_MONTHS="jan feb mar apr may jun jul aug sep oct nov dec"
VALID_DAYS="mon tue wed thu fri sat sun"

script_path="$(cd "$(dirname "$0")" && pwd)"
source $script_path/functions/errors_code.sh
source $script_path/functions/checker.sh
source $script_path/functions/copy_file.sh

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
    echo "  -exe, --execstart <value>      Script or command to run."
    echo "  -ep, --exe-param <env_vars>    Set param for script (VAR=value)."
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
        -n=*|--name=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                NAME="${1#*=}"
                shift
            fi
            ;;
        -m=*|--minute=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "${1#*=}" =~ ^([0-5]?[0-9])$|^([0-5]?[0-9])$|^([0-5]?[0-9]-[0-5]?[0-9])$|^(\*/[1-9][0-9]*)$|^([0-5]?[0-9](,[0-5]?[0-9])*)$ ]]; then
                echo "Error: Inalid format value for option $1"
                exit $ERROR_INVALID_OPTION
            else
                MIN="${1#*=}"
                shift
            fi
            ;;
        -h=*|--hour=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "${1#*=}" =~ ^([0-2]?[0-3])$|^([0-2]?[0-3]-[0-2]?[0-3])$|^(\*/[1-9][0-3]*)$|^([0-2]?[0-3](,[0-2]?[0-3])*)$ ]]; then
                echo "Error: Inalid format value for option $1"
                exit $ERROR_INVALID_OPTION
            else
                HOUR="${1#*=}"
                shift
            fi
            ;;
        -dom=*|--day-of-month=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "${1#*=}" =~ ^([1-9]|[12][0-9]|3[01])$|^([1-9]|[12][0-9]|3[01])-([1-9]|[12][0-9]|3[01])$|^(\*/[1-9][0-9]*)$|^([1-9]|[12][0-9]|3[01])(,([1-9]|[12][0-9]|3[01]))*$ ]]; then
                echo "Error: Inalid format value for option $1"
                exit $ERROR_INVALID_OPTION
            else
                DOM="${1#*=}"
                shift
            fi
            ;;
        -mon=*|--month=*)
            if ! check_argument "$1" "str"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            #elif [[ ! "$VALID_MONTHS" =~ (^|[[:space:]])"${1#*=}"($|[[:space:]]) ]] && ! [[ "${1#*=}" =~ ^[0-9\*/,-]+$ ]]; then
            elif ! [[ "${1#*=}" =~ ^(0?[1-9]|1[0-2])$|^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)$|^([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)-([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)$|^(\*/[1-9][0-9]*)$|^([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)(,([0-9]{1,2}|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec))*$ ]]; then
                echo "Error: Inalid format value for option $1"
                exit $ERROR_INVALID_OPTION
            else
               MON="${1#*=}"
               shift
            fi
            ;;
        -dow=*|--day-of-week=*)
            if ! check_argument "$1" "str"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            elif ! [[ "${1#*=}" =~ ^([1-7])$|^(mon|tue|wed|thu|fri|sat|sun)$|^([1-7])-([1-7])$|^(\*/[1-9][0-9]*)$|^([1-7]|mon|tue|wed|thu|fri|sat|sun)(,([1-7]|mon|tue|wed|thu|fri|sat|sun))*$ ]]; then
            #elif [[ ! "$VALID_DAYS" =~ (^|[[:space:]])"$DOW"($|[[:space:]]) ]] && ! [[ "$DOW" =~ ^[0-9\*/,-]+$ ]]; then
                echo "Error: Inalid format value for option $1"
                exit $ERROR_INVALID_OPTION
            else
                DOW="${1#*=}"
                shift
            fi
            ;;
        -u=*|--user=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                USER="${1#*=}"
                shift
                if ! check_user "$USER"; then
                    exit $ERROR_ARGUMENT_WRONG
                fi

                if ! check_cron_permission "$USER"; then
                    exit $ERROR_ARGUMENT_WRONG
                fi
            fi
            ;;
        -exe=*|--execstart=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                SCRIPT="${1#*=}"
                shift
            fi
            ;;
        -ep=*|--exe-param=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                # If a value is provided, assign it to script_path
                SCRIPT_PARAM="${1#*=}"
                shift
            fi
            ;;
        -cs=*|--copy-script=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                # If a value is provided, assign it to script_path
                SCRIPT_PATH="${1#*=}"
                shift
            fi
            ;;
        -cs|--copy-script)
            SCRIPT_PATH=$script_path_default
            shift
            ;;
        -csf|--copy-script-force)
            FORCE_REPLACE=true
            shift
            ;;
        -a|--append)
            APPEND=true
            shift
            ;;
        -u|--user)
            USER_FOLDER=true
            shift
            ;;
        -l=*|--log=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                LOG_FILE="${1#*=}"
                shift
                if ! check_user_write_to_file "$USER" "$LOG_FILE"; then
                    exit $ERROR_ARGUMENT_WRONG
                fi
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
    ret=$?
    if [ $ret -ne $ERROR_OK ]; then
        exit $ret
    fi
    copy_dependencies "$SCRIPT" "$SCRIPT_PATH"
    ret=$?
    if [ $ret -ne $ERROR_OK ]; then
        exit $ret
    fi
    SCRIPT=$copy_file_return
    echo "Final Script path : $SCRIPT"
fi

# Check if the user has permission to execute the script
if [ -n "$script_path" ]; then
    if ! check_user_script_permission "$SCRIPT" "$USER"; then
        exit $ERROR_PERMISSION_FAILED
    fi
fi

# Adding script param
if [ -n "$SCRIPT_PARAM" ]; then
    SCRIPT="$SCRIPT $SCRIPT_PARAM"
fi

# Selecting destination folder for cron
if [ "$USER_FOLDER" = false ]; then
    CRON_PATH='/etc/cron.d/'
    NAME=$USER'_'$NAME
    if [ -n "LOG_FILE" ]; then
        LOG_FILE="/var/log/cron_$NAME.log"
    fi
    CRON_EXEMPLE="# *  *  *  *  *  user command to be executed"
    CRON_EXE="$MIN $HOUR $DOM $MON $DOW $USER $SCRIPT >> $LOG_FILE 2>&1"
else
    CRON_PATH="/var/spool/cron/crontabs/$NAME"
    if [ -n "LOG_FILE" ]; then
        LOG_FILE="/var/log/cron_$NAME.log"
    fi
    CRON_EXEMPLE="# *  *  *  *  *  command to be executed"
    CRON_EXE="$MIN $HOUR $DOM $MON $DOW $SCRIPT >> $LOG_FILE 2>&1"
    APPEND=true
fi

# if not append, make sure to have to not override file
if [ "$APPEND" == false ]; then
    echo "Creating Job name $NAME into $CRON_PATH"
    tmpfile=$(mktemp)
    echo '.' > $tmpfile
    copy_file "$tmpfile" "${CRON_PATH%/}/$NAME"
    ret=$?
    if [ $ret -ne $ERROR_OK ]; then
        exit $ret
    fi
    CRON_PATH=$copy_file_return
    echo "Job name : $NAME created into $CRON_PATH"
    rm "$tmpfile"
    rm "$CRON_PATH"
fi

# Creating Header if not exist
if ! [ -f $CRON_PATH ]; then
    echo "# Example of job definition:" >> $CRON_PATH
    echo "# .---------------- minute (0 - 59)"  >> $CRON_PATH
    echo "# |  .------------- hour (0 - 23)" >> $CRON_PATH
    echo "# |  |  .---------- day of month (1 - 31)" >> $CRON_PATH
    echo "# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ..." >> $CRON_PATH
    echo "# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat" >> $CRON_PATH
    echo "# |  |  |  |  |" >> $CRON_PATH
    echo "$CRON_EXEMPLE" >> $CRON_PATH
fi

echo "$CRON_EXE" >> $CRON_PATH
echo "Crontab entry added successfully into $CRON_PATH."
sudo service cron reload
if [ $? -ne 0 ]; then
    echo "Error: Failed to reload cron service."
    exit 1
fi