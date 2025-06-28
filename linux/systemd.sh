#!/bin/bash

# -------------------------------------------------------------------
# SystemTool
#
# Script to generate, register, and remove systemd service files
# Description: This script allows you to generate a systemd service file
# with all possible parameters and options, register it, and remove it.
# Version: 1.0.4
# Author: Torayld
# -------------------------------------------------------------------

# Script version
SCRIPT_VERSION="1.0.4"

# Default values
description="Service managed by the script"
documentation_default="MadeBySystemTool"
documentation=$documentation_default
after=""
before=""
wants=""
wantedby='multi-user.target'
requires=""
conflicts=""
type="simple"
execstart=""
user="root"
group="root"
restart="always"
restartsec="3"
timeoutsec="120"
pidfile=""
ambient_capabilities=""
working_directory=""
environment=""
environment_file=""
kill_mode="process"
timeoutstopsec="10"
syslog_identifier=""
standard_output="journal"
standard_error="journal"
script_path_default="/usr/local/bin"
script_path=""
script_path_force=''
remove_script=false
name="myservice"  # Default base name for the service

script_path="$(cd "$(dirname "$0")" && pwd)"
script_name="$(basename "$0")"
source $script_path/functions/errors_code.sh
source $script_path/functions/checker.sh
source $script_path/functions/copy_file.sh

# Print version information
print_version() {
    echo "$script_name version $SCRIPT_VERSION"
    exit $ERROR_OK
}

display_help() {
    echo "Usage: $script_name [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --description=<string>     Service description."
    echo "  -doc, --documentation=<string> Documentation URL."
    echo "  -a, --after=<string>           List of services to start after this one."
    echo "  -b, --before=<string>          List of services to start before this one."
    echo "  -w, --wants=<string>           List of services this one wants."
    echo "  -wb, --wantedby=<string>       List of services that want this one."
    echo "  -r, --requires=<string>        List of services this one requires."
    echo "  -cf, --conflicts=<string>      List of services that conflict with this one."
    echo "  -t, --type=<string>            Service type (simple, forking, oneshot, etc.)."
    echo "  -exe, --execstart=<string>     Command to start the service."
    echo "  -u, --user=<string>            User to run the service as."
    echo "  -g, --group=<string>           Group to run the service as."
    echo "  -cs, --copy-script=<path>      Specifies the path of the script to copy (default $script_path_default)."
    echo "  -csf, --copy-script-force      Force overwrite the script file without confirmation."
    echo "  -rm, --remove=<service>        Remove the specified systemd service."
    echo "  -p, --purge                    Purge the associated script file."
    echo "  -env, --environment=<env_vars> Set environment variables ("VAR='value' VAR2='value2'")."
    echo "  -km, --kill-mode=<mode>        Kill mode (process, control-group)."
    echo "  -tss, --timeoutstopsec=<time>  Timeout for stopping the service."
    echo "  -n, --name=<name>              Specify a custom name for the service (default: myservice)."
    echo "  -v, --version                  Show script version."
    echo "  -er, --error                   Display error codes and their meanings."
    echo "  -h, --help                     Display this help."
    echo ""
    echo "Examples:"
    echo "  $script_name --description \"My custom service\" --exe \"/path/to/executable\" --user \"myuser\""
    echo "  $script_name --exe \"/path/to/executable\" --type forking --env \"MY_VAR=somevalue\""
    echo "  $script_name --exe \"/path/to/executable\" --documentation \"https://docs.example.com\""
    echo "  $script_name --remove-systemd \"myservice1.service\" --remove-script-file"
    echo "  $script_name --copy-script /path/to/script --csf --exe \"/path/to/executable\""
    echo "  $script_name --name \"customservice\" --exe \"/path/to/executable\""
}

# Generate available service file name
generate_service_filename() {
    local service_filename="${name}1.service"
    local counter=1

    # Check if the file exists, increment the number if necessary
    while [ -f "/etc/systemd/system/$service_filename" ]; do
        counter=$((counter + 1))
        service_filename="${name}${counter}.service"
    done

    echo "$service_filename"
}

# Remove the systemd service and its script
remove_systemd_service() {
    if [ -z "$1" ]; then
        echo "Error: You must specify the service name to remove."
        exit $ERROR_MISSING_ARGUMENT
    fi

    service_to_remove="$1"
    service_file="/etc/systemd/system/$service_to_remove"

    # Check if the service file exists
    if [ ! -f "$service_file" ]; then
        echo "Error: The service file $service_file does not exist."
        exit $ERROR_INVALID_FILE
    fi

    # Check if the service file contains 'autoscript' in the Documentation field
    if ! grep -q "Documentation=.*$documentation_default" "$service_file"; then
        echo "Error: The service file $service_file does not contain '$documentation_default' in the Documentation field."
        exit $ERROR_SERVICE_INVALID_DOC_TAG
    fi

    echo "Removing systemd service: $service_to_remove..."

    # Stop and disable the service
    sudo systemctl stop "$service_to_remove"
    sudo systemctl disable "$service_to_remove"

    # Extract the script path from the service file
    script_path_to_remove=$(grep -oP '(?<=^ExecStart=).+' "$service_file" | tr -d ' ')

    # Check if the script file exists
    if [ -n "$script_path_to_remove" ]; then
        if [ ! -f "$script_path_to_remove" ]; then
            echo "Associated script file not found: $script_path_to_remove."
        else
            # if an environment is set, send it to the script
            if [ -n "$environment" ]; then
                echo "Calling the script with the environment variables to clean"
                $script_path_to_remove $environment
            fi
            if [ "$remove_script" = true ]; then
                # Confirm removal of the associated script file
                read -p "Do you want to remove the associated script file $script_path_to_remove? (y/n): " response
                if [[ "$response" == "y" || "$response" == "Y" ]]; then
                    echo "Removing associated script: $script_path_to_remove..."
                    sudo rm -f "$script_path_to_remove"
                    if [ $? -ne 0 ]; then
                        echo "Error: Unable to remove the script file."
                        exit $ERROR_SERVICE_SCRIPT_REMOVE_FAILED
                    fi
                else
                    echo "The script file was not removed."
                fi
            fi
        fi
    else
        echo "No script file associated or not found."
    fi
    
    # Remove the service file
    sudo rm -f "$service_file"
    if [ $? -ne 0 ]; then
        echo "Error: Unable to remove the service file."
        exit $ERROR_SERVICE_FILE_REMOVE_FAILED
    fi
    sudo systemctl daemon-reload
    if [ $? -ne 0 ]; then
        echo "Error: Failed to reload systemd."
        exit $ERROR_SERVICE_RELOAD_FAILED
    fi

    echo "Systemd service $service_to_remove removed."
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
        -d=*|--description=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                description="${1#*=}"
                shift
            fi
            ;;
        -doc=*|--documentation=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                documentation=$documentation_default"${1#*=}"
                shift
            fi
            ;;
        -a=*|--after=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                after="${1#*=}"
                shift
            fi
            ;;
        -b=*|--before=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                before="${1#*=}"
                shift
            fi
            ;;
        -w=*|--wants=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                wants="${1#*=}"
                shift
            fi
            ;;
        -wb=*|--wantedby=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                wantedby="${1#*=}"
                shift
            fi
            ;;
        -r=*|--requires=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                requires="${1#*=}"
                shift
            fi
            ;;
        -cf=*|--conflicts=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                conflicts="${1#*=}"
                shift
            fi
            ;;
        -t=*|--type=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                type="${1#*=}"
                shift
            fi
            ;;
        -exe=*|--execstart=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                execstart="${1#*=}"
                shift
            fi
            ;;
        -u=*|--user=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                user="${1#*=}"
                shift
                if ! check_user "$USER"; then
                    exit $ERROR_ARGUMENT_WRONG
                fi
            fi
            ;;
        -g=*|--group=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                group="${1#*=}"
                shift
            fi
            ;;
        -cs|--copy-script)
            script_path="$script_path_default"
            shift
            ;;
        -cs=*|--copy-script=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                script_path="${1#*=}"
                shift
            fi
            ;;
        -csf|--copy-script-force)
            script_path_force='--force'
            shift
            ;;
        -env=*|--environment=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                environment="${1#*=}"
                shift
            fi
            ;;
        -km=*|--kill-mode=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                kill_mode="${1#*=}"
                shift
            fi
            ;;
        -tss=*|--timeoutstopsec=*)
            if ! check_argument "$1" "int"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                timeoutstopsec="${1#*=}"
                shift
            fi
            ;;
        -n=*|--name=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                name="${1#*=}"
                shift
            fi
            ;;
        -rm=*|--remove=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                remove="${1#*=}"
                shift
            fi
            ;;
        -p|--purge)
            remove_script=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit $ERROR_INVALID_OPTION
            ;;
    esac
done

if [ -n "$remove" ]; then
    remove_systemd_service "$remove"
    exit $ERROR_OK
fi

# Validate required fields
if [ -z "$execstart" ]; then
    echo "Error: ExecStart is required."
    exit $ERROR_MISSING_ARGUMENT
fi

# Call the function to verify and copy the script
if [ -n "$script_path" ]; then
    echo "Copying $execstart to $script_path"
    copy_file "$execstart" "$script_path" $script_path_force
    ret=$?
    if [ $ret -ne $ERROR_OK ]; then
        exit $ret
    fi
    execstart=$copy_file_return
    copy_dependencies "$execstart" "$script_path"
    ret=$?
    if [ $ret -ne $ERROR_OK ]; then
        exit $ret
    fi
    echo "Final Script path : $execstart"
fi

if [ -n "$script_path" ]; then
    if ! check_user_script_permission "$execstart" "$user"; then
        exit $ERROR_PERMISSION_FAILED
    fi
fi

if [ -n "$restart" ]; then
    restart_valid_values=("no" "on-success" "on-failure" "on-abnormal" "on-watchdog" "on-abort" "always")
    is_valid_restart=false
    for value in "${restart_valid_values[@]}"; do
        if [ "$restart" == "$value" ]; then
            is_valid_restart=true
            break
        fi
    done
    if [ "$is_valid_restart" = false ]; then
        echo "Error: Invalid value for Restart. Valid values are: ${restart_valid_values[*]}"
        exit $ERROR_ARGUMENT_WRONG
    fi
fi

# Create systemd service file
service_file=$(generate_service_filename)

# Start creating the systemd service file
sudo bash -c "cat > /etc/systemd/system/$service_file <<EOF
[Unit]
$([ -n "$description" ] && echo "Description=$description")
$([ -n "$documentation" ] && echo "Documentation=$documentation")
$([ -n "$after" ] && echo "After=$after")
$([ -n "$before" ] && echo "Before=$before")
$([ -n "$wants" ] && echo "Wants=$wants")
$([ -n "$requires" ] && echo "Requires=$requires")
$([ -n "$conflicts" ] && echo "Conflicts=$conflicts")

[Service]
$([ -n "$type" ] && echo "Type=$type")
$([ -n "$execstart" ] && echo "ExecStart=$execstart")
$([ -n "$user" ] && echo "User=$user")
$([ -n "$group" ] && echo "Group=$group")
$([ -n "$restart" ] && echo "Restart=$restart")
$([ -n "$restartsec" ] && echo "RestartSec=$restartsec")
$([ -n "$timeoutsec" ] && echo "TimeoutSec=$timeoutsec")
$([ -n "$pidfile" ] && echo "PIDFile=$pidfile")
$([ -n "$ambient_capabilities" ] && echo "AmbientCapabilities=$ambient_capabilities")
$([ -n "$working_directory" ] && echo "WorkingDirectory=$working_directory")
$([ -n "$environment" ] && echo "Environment=$environment")
$([ -n "$environment_file" ] && echo "EnvironmentFile=$environment_file")
$([ -n "$kill_mode" ] && echo "KillMode=$kill_mode")
$([ -n "$timeoutstopsec" ] && echo "TimeoutStopSec=$timeoutstopsec")
$([ -n "$syslog_identifier" ] && echo "SyslogIdentifier=$syslog_identifier")
$([ -n "$standard_output" ] && echo "StandardOutput=$standard_output")
$([ -n "$standard_error" ] && echo "StandardError=$standard_error")

[Install]
WantedBy=${install_wantedby:-multi-user.target}
EOF"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create the service."
    exit $ERROR_SERVICE_FILE_CREATION_FAILED
fi

echo "Systemd service file created at /etc/systemd/system/$service_file"

# Reload systemd, enable, and start the service
sudo systemctl daemon-reload
if [ $? -ne 0 ]; then
    echo "Error: Failed to reload systemd."
    exit $ERROR_SERVICE_RELOAD_FAILED
fi
sudo systemctl enable "$service_file"
if [ $? -ne 0 ]; then
    echo "Error: Failed to enable the service."
    exit $ERROR_INSTALL_FAILED
fi
sudo systemctl start "$service_file"
if [ $? -ne 0 ]; then
    echo "Error: Failed to start the service."
    exit $ERROR_SERVICE_START_FAILED
fi

echo "Service started successfully."
exit $ERROR_OK