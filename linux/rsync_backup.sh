#!/bin/bash
# -------------------------------------------------------------------
# Manage IPv6 enable/disable settings on your Linux system
# Version: 1.0.0
# Author: Torayld
# -------------------------------------------------------------------
SCRIPT_VERSION="1.0.0"

script_path="$(cd "$(dirname "$0")" && pwd)"
source $script_path/functions/errors_code.sh
source $script_path/functions/checker.sh

# Print version information
print_version() {
    echo "$0 version $SCRIPT_VERSION"
    exit $ERROR_OK
}

display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --source <value>           Source directory to backup."
    echo "  -d, --dest <value>             Destination directory for the backup."
    echo "  -l, --log <value>              Log file where the output of the command should be redirected."
    echo "  -e, --exclude <value>          Add a file or directory to exclude (can be used multiple times)."
    echo "  -v, --version                  Show script version."
    echo "  -er, --error                   Display error codes and their meanings."
    echo "  -h, --help                     Display this help."
    echo ""
}

# Rsync backup function
# Usage: rsync_backup <source> <dest> <log_file> [excludes...]
# parameters:
#   source: Source directory to backup.
#   dest: Destination directory for the backup.
#   log_file: Log file where the output of the command should be redirected.
#   excludes: Optional list of directories or files to exclude from the backup.
# Returns 0 on success, non-zero on failure.
#
# example:
#   excludes_array=("@eaDir" "#recycle" "Thumbs.db" ".DS_Store")
#   rsync_backup "/path/to/source" "/path/to/dest" "/path/to/logfile.log" "${excludes_array[@]}"
rsync_backup() {
    local source="$1"
    local dest="$2"
    local log="$3"
    shift 3
    local excludes=("$@")

    local rsync_opts=(
        -hvazP
        --delete-before
        --no-o
        --no-g
        --no-perms
    )

    # Ajouter chaque élément du tableau d'exclusions
    for exclude in "${excludes[@]}"; do
        rsync_opts+=(--exclude="$exclude")
    done

    # Exécution de la commande rsync avec journalisation
    rsync "${rsync_opts[@]}" "$source" "$dest" > "$log" 2>&1
}

SOURCE=""
DEST=""
LOG_FILE=""
EXCLUDES=()

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
        -s=*|--source=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                SOURCE="${1#*=}"
                shift
            fi
            ;;
        -d=*|--dest=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                DEST="${1#*=}"
                shift
            fi
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
        -e=*|--exclude=*)
            if ! check_argument "$1"; then
                echo "Error: Missing value for option $1"
                exit $ERROR_MISSING_ARGUMENT
            else
                EXCLUDES+=("${1#*=}")
                shift
            fi
            ;;
        *)
            echo "Unknown option: $1"
            exit $ERROR_INVALID_OPTION
            ;;
    esac
done

rsync_backup "$SOURCE" "$DEST" "$LOG_FILE" "${EXCLUDES[@]}"
if [ $? -ne 0 ]; then
    echo "Error: Rsync backup failed. Check the log file for details."
    exit $ERROR_RSYNC_FAILED
else
    echo "Backup completed successfully."
    exit $ERROR_OK
fi