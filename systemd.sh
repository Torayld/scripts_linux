#!/bin/bash

# -------------------------------------------------------------------
# SystemTool
#
# Script to generate, register, and remove systemd service files
# Description: This script allows you to generate a systemd service file
# with all possible parameters and options, register it, and remove it.
# Version: 1.0.1
# Author: Torayld
# -------------------------------------------------------------------

# Script version
SCRIPT_VERSION="1.0.1"

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
syslog_identifier=""
standard_output="journal"
standard_error="journal"
script_path_default="/usr/local/bin"
script_path=""
force_replace=false
remove_script=false
base_name="myservice"  # Default base name for the service

# Print version information
print_version() {
    echo "$0 version $SCRIPT_VERSION"
    exit $ERROR_OK
}

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --description <string>     Service description."
    echo "  -doc, --documentation <string> Documentation URL."
    echo "  -a, --after <string>           List of services to start after this one."
    echo "  -b, --before <string>          List of services to start before this one."
    echo "  -w, --wants <string>           List of services this one wants."
    echo "  -wb, --wantedby <string>       List of services that want this one."
    echo "  -r, --requires <string>        List of services this one requires."
    echo "  -cf, --conflicts <string>      List of services that conflict with this one."
    echo "  -t, --type <string>            Service type (simple, forking, oneshot, etc.)."
    echo "  -exe, --execstart <string>     Command to start the service."
    echo "  -u, --user <string>            User to run the service as."
    echo "  -g, --group <string>           Group to run the service as."
    echo "  -cs, --copy-script <path>      Specifies the path of the script to copy (default $script_path_default)."
    echo "  -csf, --copy-script-force      Force overwrite the script file without confirmation."
    echo "  -rm, --remove <service>        Remove the specified systemd service."
    echo "  -p, --purge                    Purge the associated script file."
    echo "  -env, --environment <env_vars> Set environment variables (VAR=value)."
    echo "  -n, --name <name>              Specify a custom name for the service (default: myservice)."
    echo "  -v, --version                  Show script version."
    echo "  -er, --error                   Display error codes and their meanings."
    echo "  -h, --help                     Display this help."
    echo ""
    echo "Examples:"
    echo "  $0 --description \"My custom service\" --exe \"/path/to/executable\" --user \"myuser\""
    echo "  $0 --exe \"/path/to/executable\" --type forking --env \"MY_VAR=somevalue\""
    echo "  $0 --exe \"/path/to/executable\" --documentation \"https://docs.example.com\""
    echo "  $0 --remove-systemd \"myservice1.service\" --remove-script-file"
    echo "  $0 --copy-script /path/to/script --csf --exe \"/path/to/executable\""
    echo "  $0 --name \"customservice\" --exe \"/path/to/executable\""
}

# Error codes (documenting the exit codes)
ERROR_OK=0              # OK
ERROR_INVALID_OPTION=10  # Invalid or unknown option provided
ERROR_MISSING_ARGUMENT=11  # Missing argument for a required option
ERROR_OPTION_CONFLICT=12  # Conflict between 2 arguments
ERROR_INVALID_FILE=20    # The file does not exist or is not valid
ERROR_NOT_EXECUTABLE=21   # The file is not executable
ERROR_FILE_COPY_FAILED=22 # The file copy operation failed
ERROR_PERMISSION_FAILED=23 # The chmod operation failed
ERROR_INSTALL_FAILED=24  # The installation failed
ERROR_UNINSTALL_FAILED=25  # The uninstallation failed
ERROR_SERVICE_START_FAILED=60 # The service failed to start
ERROR_SERVICE_FILE_CREATION_FAILED=61 # The systemd service file creation failed
ERROR_SERVICE_REMOVE_FAILED=70 # Failed to remove systemd service
ERROR_SERVICE_INVALID_DOC_TAG=71 # The service file does not contain "autoscript" in the Documentation tag
ERROR_SCRIPT_REMOVE_FAILED=72 # Unable to remove the script file
ERROR_SERVICE_FILE_NOT_FOUND=73 # The service file does not exist
ERROR_SERVICE_FILE_REMOVE_FAILED=74 # Unable to remove the service file


# Display error codes
display_error_codes() {
    echo "Error Codes and their Meanings:"
    echo "---------------------------------------------------"
    echo " $ERROR_INVALID_OPTION    : Invalid or unknown option provided."
    echo " $ERROR_MISSING_ARGUMENT  : Missing argument for a required option."
    echo " $ERROR_OPTION_CONFLICT   : Conflict between 2 arguments."
    echo " $ERROR_INVALID_FILE      : The file does not exist or is not valid."
    echo " $ERROR_NOT_EXECUTABLE    : The file is not executable."
    echo " $ERROR_FILE_COPY_FAILED  : The file copy operation failed."
    echo " $ERROR_PERMISSION_FAILED : The chmod operation failed."
    echo " $ERROR_INSTALL_FAILED    : The installation failed."
    echo " $ERROR_UNINSTALL_FAILED  : The uninstallation failed."
    echo " $ERROR_SERVICE_START_FAILED : The service failed to start."
    echo " $ERROR_MISSING_ARGUMENT  : Missing argument for a required option."
    echo " $ERROR_SERVICE_FILE_CREATION_FAILED : The systemd service file creation failed."
    echo " $ERROR_SERVICE_REMOVE_FAILED : Failed to remove systemd service."
    echo " $ERROR_SERVICE_INVALID_DOC_TAG : The service file does not contain \"autoscript\" in the Documentation tag."
    echo " $ERROR_SCRIPT_REMOVE_FAILED : Unable to remove the script file."
    echo " $ERROR_SERVICE_FILE_NOT_FOUND : The service file does not exist."
    echo " $ERROR_SERVICE_FILE_REMOVE_FAILED : Unable to remove the service file."
    echo "---------------------------------------------------"
}

# Generate available service file name
generate_service_filename() {
    local service_filename="${base_name}1.service"
    local counter=1

    # Check if the file exists, increment the number if necessary
    while [ -f "/etc/systemd/system/$service_filename" ]; do
        counter=$((counter + 1))
        service_filename="${base_name}${counter}.service"
    done

    echo "$service_filename"
}

# Check if files are identical
check_files_identical() {
    local source_file="$1"
    local target_file="$2"

    # Compare source and target files
    if cmp -s "$source_file" "$target_file"; then
        echo "Files are identical, no copy needed."
        return 0  # Files are identical
    else
        return 1  # Files are different
    fi
}

# Ask for file replacement confirmation
ask_for_replacement() {
    local source_file="$1"
    local target_file="$2"
    
    # Display file sizes and dates
    echo "Source file size: $(stat --format=%s "$source_file") bytes, modified on $(stat --format=%y "$source_file")."
    echo "Target file size: $(stat --format=%s "$target_file") bytes, modified on $(stat --format=%y "$target_file")."
    
    # Prompt for confirmation to replace
    read -p "Do you want to replace the file $target_file? (y/n): " response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        return 0  # User wants to replace the file
    else
        return 1  # User doesn't want to replace the file
    fi
}

# Function to verify that the directory exists, create it if not, and copy the script
verify_and_copy_script() {
    local script_source="$1"
    if [ ! -f "$script_source" ]; then
        echo "Error: File not found $script_source."
        exit $ERROR_INVALID_FILE
    fi

    local destination_dir="$2"

    if [ -n "$destination_dir" ]; then
        # Check if the destination directory exists
        if [ ! -d "$destination_dir" ]; then
            echo "Directory $destination_dir does not exist. Creating it now..."
            sudo mkdir -p "$destination_dir"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to create directory $destination_dir."
                exit $ERROR_INVALID_FILE
            fi
        fi
        
        # Extract the filename from the source path
        local filename=$(basename "$script_source")
        destination_file="$destination_dir/$filename"

        # Check if the script file already exists and copy it
        if [ -f "$destination_file" ]; then
            check_files_identical "$script_source" "$destination_file"
            if [ $? -eq 1 ]; then
                if [ "$force_replace" = true ]; then
                    echo "Force replacing the script file..."
                    sudo cp "$script_source" "$destination_file"
                    if [ $? -ne 0 ]; then
                        echo "Error: Failed to copy the script to $destination_file."
                        exit $ERROR_FILE_COPY_FAILED
                    fi
                else
                    # Ask for confirmation if files are different
                    if ask_for_replacement "$script_source" "$destination_file"; then
                        sudo cp "$script_source" "$destination_file"
                        if [ $? -ne 0 ]; then
                            echo "Error: Failed to copy the script to $destination_file."
                            exit $ERROR_FILE_COPY_FAILED
                        fi
                    else
                        echo "The script file was not replaced."
                        return 0
                    fi
                fi
            fi
        else
            # If the script doesn't exist, just copy it
            sudo cp "$script_source" "$destination_file"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to copy the script to $destination_file."
                exit $ERROR_FILE_COPY_FAILED
            fi
        fi
    else
        destination_file="$(pwd)/$(basename "$script_source")"
        destination_file="$destination_file" | sed 's|^\.\//\+|./|'
    fi

    # If it's a shell script (.sh), set executable permissions
    if [[ "$destination_file" == *.sh ]]; then
        sudo chmod +x "$destination_file"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to set executable permissions on $destination_file."
            exit $ERROR_PERMISSION_FAILED
        fi
        echo "Executable permissions set on $destination_file."
    fi

    echo "Script location : $destination_file."
    return 0
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
                        exit $ERROR_SCRIPT_REMOVE_FAILED
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
        -d|--description)
            description="$2"
            shift 2
            ;;
        -doc|--documentation)
            documentation=$documentation_default"$2"
            shift 2
            ;;
        -a|--after)
            after="$2"
            shift 2
            ;;
        -b|--before)
            before="$2"
            shift 2
            ;;
        -w|--wants)
            wants="$2"
            shift 2
            ;;
        -wb|--wantedby)
            wantedby="$2"
            shift 2
            ;;
        -r|--requires)
            requires="$2"
            shift 2
            ;;
        -cf|--conflicts)
            conflicts="$2"
            shift 2
            ;;
        -t|--type)
            type="$2"
            shift 2
            ;;
        -exe|--execstart)
            execstart="$2"
            shift 2
            ;;
        -u|--user)
            user="$2"
            shift 2
            ;;
        -g|--group)
            group="$2"
            shift 2
            ;;
        -cs|--copy-script)
            # Check if a value is provided for -cs
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                # If no value is provided or the value is another argument (starts with -), use the default path
                script_path=$script_path_default
                echo "No path provided for -cs. Using default path: $script_path_default"
                shift
            else
                # If a value is provided, assign it to script_path
                script_path="$2"
                shift 2
            fi
            ;;
        -csf|--copy-script-force)
            force_replace=true
            shift 1
            ;;
        -env|--environment)
            environment="$2"
            shift 2
            ;;
        -n|--name)
            base_name="$2"
            shift 2
            ;;
        -rm|--remove)
            remove="$2"
            shift 2
            ;;
        -p|--purge)
            remove_script=true
            shift 1
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
verify_and_copy_script "$execstart" "$script_path"

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
$([ -n "$execstart" ] && echo "ExecStart=$destination_file")
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
sudo systemctl enable "$service_file"
sudo systemctl start "$service_file"

if [ $? -ne 0 ]; then
    echo "Error: Failed to start the service."
    exit $ERROR_SERVICE_START_FAILED
fi

echo "Service started successfully."
exit $ERROR_OK